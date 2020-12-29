# This class is heavily based off, if not entirely taken from, ActiveRecord::Sanitization::ClassMethods ()
# It will sanitize input as well as do some parsing/handeling of arguments passed.

class Sanitization
  #NOTE: This is the only method that has been modified from the official ActiveRecord module(s).
  #      The reason being so that arrays are not needed as arguments.
  #       
  #      All of the following are acceptable:
  #       case 0: sanitize("branch_id = {#sqlinjection}")                #pwned
  #       case 1: sanitize(["branch_id=? or location_id=?", foo, bar])
  #       case 2: sanitize("branch_id=? or location_id=?", [foo, bar])
  #       case 3: sanitize("branch_id=? or location_id=?", foo, bar)     #prefered  
  def sanitize(condition)
      return nil if condition.blank?

      case condition
      when Array; sanitize_sql_array(condition) 
      else 
        statement, *values = condition
        sanitize_sql_array([statment, *values])
      end
  end

  # Accepts an array of conditions. The array has each value
  # sanitized and interpolated into the SQL statement.
  #
  #   sanitize_sql_array(["name=? and group_id=?", "foo'bar", 4])
  #   # => "name='foo''bar' and group_id=4"
  #
  #   sanitize_sql_array(["name=:name and group_id=:group_id", name: "foo'bar", group_id: 4])
  #   # => "name='foo''bar' and group_id=4"
  #
  #   sanitize_sql_array(["name='%s' and group_id='%s'", "foo'bar", 4])
  #   # => "name='foo''bar' and group_id='4'"
  def sanitize_sql_array(ary)
    statement, *values = ary
    if values.first.is_a?(Hash) && /:\w+/.match?(statement)
      replace_named_bind_variables(statement, values.first)
    elsif statement.include?("?")
      replace_bind_variables(statement, values)
    elsif statement.blank?
      statement
    else
      statement % values.collect { |value| connection.quote_string(value.to_s) }
    end
  end

  def replace_bind_variables(statement, values)
    raise_if_bind_arity_mismatch(statement, statement.count("?"), values.size)
    bound = values.dup
    c = connection
    statement.gsub(/\?/) do
      replace_bind_variable(bound.shift, c)
    end
  end

  def replace_bind_variable(value, c = connection)
    if ActiveRecord::Relation === value
      value.to_sql
    else
      quote_bound_value(value, c)
    end
  end

  def replace_named_bind_variables(statement, bind_vars)
    statement.gsub(/(:?):([a-zA-Z]\w*)/) do |match|
      if $1 == ":" # skip postgresql casts
        match # return the whole match
      elsif bind_vars.include?(match = $2.to_sym)
        replace_bind_variable(bind_vars[match])
      else
        raise PreparedStatementInvalid, "missing value for :#{match} in #{statement}"
      end
    end
  end

end