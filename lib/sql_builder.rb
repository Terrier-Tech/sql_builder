require "sql_builder/version"
require "sql_builder/query_result"
require "active_record"

# Monkey Patch
module ActiveRecord
  class Base
    class << self
      public :sanitize_sql_array
    end
  end
end

# provides a builder interface for creating SQL queries
class SqlBuilder
  DEFAULT_LIMIT = 10000

  # attributes that are arrays and should be included in serialization
  ARRAY_ATTRS = %w[selects clauses distincts froms joins order_bys group_bys havings withs]

  attr_accessor(*ARRAY_ATTRS)

  # attributes that are scalars and should be included in serialization
  SCALAR_ATTRS = %w[the_limit make_objects row_offset fetch_next the_dialect]
  attr_accessor(*SCALAR_ATTRS)

  @@default_make_objects = true

  def self.default_make_objects=(val)
    @@default_make_objects = val
  end

  class << self
    # This should mimic the behavior of ActiveRecord::Base.default_timezone
    # i.e. it's either :utc (default) or :local
    attr_accessor :default_timezone

    @default_timezone = :utc
  end

  def initialize
    ARRAY_ATTRS.each do |attr|
      self.send "#{attr}=", []
    end

    @make_objects = @@default_make_objects
    @the_limit = DEFAULT_LIMIT
    @limit_warning = true
    @row_offset = nil
    @fetch_next = nil
    @the_dialect = :psql
  end


  ## Dialects

  DIALECTS = %i(psql mssql)

  def dialect(new_dialect=nil)
    if new_dialect.nil?
      return @the_dialect # make this method act like a getter as well
    end
    new_dialect = new_dialect.to_sym
    unless DIALECTS.index new_dialect
      raise "Invalid dialect #{new_dialect}, must be one of: #{DIALECTS.join(', ')}"
    end
    @the_dialect = new_dialect
    self
  end

  def from(table, as=nil)
    if as
      @froms << "#{table} as #{as}"
    else
      @froms << table
    end
    self
  end

  def select(columns, table=nil, prefix=nil)
    columns = [columns] unless columns.is_a? Array
    table_part = table ? "#{table}." : ''
    columns.each do |c|
      statement = "#{table_part}#{c}"
      if prefix
        statement += " #{prefix}#{c}"
      end
      @selects << statement
    end
    self
  end

  def with(w)
    @withs << w
    self
  end

  def get_join_mode_vars(arg1, arg2, arg3)
    # 1 and 2 arg options can only join parent tables
    if arg2.nil? && arg3.nil?
      # 'work_orders AS wo'
      table = arg1.split(' ').first
      as = arg1.split(' ').last

      if self.froms.blank?
        raise 'must declare a from statement to use 1 argument join'
      end
      child_table = self.froms.first.split(' ').last
      foreign_key = "#{table.singularize}_id"
      clause = "#{child_table}.#{foreign_key} = #{as}.id"
    elsif arg3.nil?
      # 'work_orders AS wo', 'inspection_items.work_order_id'
      table = arg1.split(' ').first
      as = arg1.split(' ').last
      clause = "#{as}.id = #{arg2}"
    else
      table = arg1
      as = arg2
      clause = arg3
    end
    [table, as, clause]
  end


  def left_join(arg1, arg2=nil, arg3=nil)
    table, as, clause = get_join_mode_vars arg1, arg2, arg3
    @joins << "LEFT JOIN #{table} AS #{as} ON #{clause}"
    self
  end

  def inner_join(arg1, arg2=nil, arg3=nil)
    table, as, clause = get_join_mode_vars arg1, arg2, arg3
    @joins << "INNER JOIN #{table} AS #{as} ON #{clause}"
    self
  end

  def outer_join(arg1, arg2=nil, arg3=nil)
    table, as, clause = get_join_mode_vars arg1, arg2, arg3
    @joins << "LEFT OUTER JOIN #{table} AS #{as} ON #{clause}"
    self
  end

  def right_join(arg1, arg2=nil, arg3=nil)
    table, as, clause = get_join_mode_vars arg1, arg2, arg3
    @joins << "RIGHT JOIN #{table} AS #{as} ON #{clause}"
    self
  end

  def parse_where(clause)
    clause.each_with_index do |entry, i|
      if entry.is_a?(Array)
        template = clause[0].split('?')
        template = template.map.with_index {|phrase, index| index==i-1 ? phrase : phrase+'?' }
        template.insert(i, '('+('?'*entry.length).split('').join(',')+')')
        clause[0] = template.join('')
        clause.delete_at(i)
        clause.insert(i, *entry)
      end
    end
  end

  def where(*clause)
    @clauses << sanitize(parse_where(clause))
    self
  end

  def having(clause)
    @havings << clause
    self
  end

  def group_by(expression)
    @group_bys << expression
    self
  end

  def order_by(expression)
    @order_bys << expression
    self
  end

  def limit(limit, limit_warning=false)
    @limit_warning = limit_warning
    @the_limit = limit
    self
  end

  def offset(offset)
    @row_offset = offset
    self
  end

  def fetch(fetch)
    @fetch_next = fetch
    self
  end

  def distinct(distinct, table=nil)
    distinct = [distinct] unless distinct.is_a? Array
    table_part = table ? "#{table}." : ''
    distinct.each do |d|
      statement = "#{table_part}#{d}"
      @distincts << statement
    end
    self
  end

  def to_sql
    _distinct = ''
    if @distincts and @distincts.count > 0
      if @the_dialect == :mssql
        _distinct += 'DISTINCT ('
        _distinct += @distincts.join(', ')
        _distinct += ')'
      else
        _distinct += 'DISTINCT ON ('
        _distinct += @distincts.join(', ')
        _distinct += ')'
      end
    end

    withs_s = @withs.map do |w|
      "WITH #{w}"
    end.join(' ')

    top_s = if @the_limit && @the_dialect == :mssql
      "TOP #{@the_limit}"
    else
      ''
    end

    froms_s = @froms.empty? ? '' : "FROM #{@froms.join(', ')}"

    s = "#{withs_s} SELECT #{top_s} #{_distinct} #{@selects.join(', ')} #{froms_s} #{@joins.join(' ')}"
    if @clauses.length > 0
      clauses_s = @clauses.map{|c| "(#{c})"}.join(' AND ')
      s += "  WHERE #{clauses_s}"
    end
    if @group_bys.length > 0
      s += " GROUP BY #{@group_bys.join(', ')}"
    end
    if @havings.length > 0
      s += " HAVING #{@havings.join(' AND ')}"
    end
    if @order_bys.length > 0
      s += " ORDER BY #{@order_bys.join(', ')}"
    end
    if @the_limit && @the_dialect != :mssql
      s += " LIMIT #{@the_limit}"
    end
    if @row_offset && @the_dialect == :mssql
      s += " OFFSET #{@row_offset} ROWS"
    elsif @row_offset
      s += " OFFSET #{@row_offset}"
    end
    if @fetch_next && @the_dialect == :mssql
      s += " FETCH NEXT #{@fetch_next} ROWS ONLY"
    elsif @fetch_next
      s += " FETCH FIRST #{@fetch_next} ROWS ONLY"
    end
    s
  end

  def sanitize(query)
    query.each_with_index do |entry, i| #need to escape %
      if entry.is_a?(String)
        query[i] = entry.gsub('%', '%%')
      end
    end
    if ActiveRecord::Base.respond_to? :sanitize_sql
      ActiveRecord::Base.sanitize_sql query
    else
      ActiveRecord::Base.sanitize_sql_array query
    end
  end

  def check_result_limit!(query)
    if query.count == @the_limit and @limit_warning
      raise "Query result has exactly #{@the_limit} results, which is the same as the limit"
    end
    query
  end

  def exec
    results = ActiveRecord::Base.connection.execute(self.to_sql).to_a
    if @make_objects
      check_result_limit!(QueryResult.new results)
    else
      check_result_limit!(results)
    end
  end

  def dup
    other = SqlBuilder.new
    (ARRAY_ATTRS + SCALAR_ATTRS).each do |attr|
      other.send "#{attr}=", self.send(attr).dup
    end
    other.make_objects = @make_objects
    other.the_limit = @the_limit
    other
  end

  def as_raw
    @make_objects = false
    self
  end

  def as_objects
    @make_objects = true
    self
  end

  def self.from_raw(raw)
    builder = SqlBuilder.new
    (ARRAY_ATTRS + SCALAR_ATTRS).each do |attr|
      if raw[attr]
        builder.send "#{attr}=", raw[attr]
      end
    end
    builder
  end
end
