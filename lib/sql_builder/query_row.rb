# base class for objects representing a single row in a query result
class QueryRow

  attr_reader :raw

  def initialize(result, raw)
    @result = result
    @raw = raw
  end

  def [](key)
    @raw[key.to_s]
  end

  def []=(key, value)
    @raw[key.to_s] = value
  end

  def inspect
    '{' + @result.columns.map{|col| "#{col[:name]}=#{self.send(col[:name])}"}.join(', ') + '}'
  end

  def serialize_value(column)
    value = self.send(column[:name])
    case column[:type]
    when :time
      value&.to_s
    else
      value
    end
  end

  def as_json(options={})
    attrs = {}
    @result.columns.each do |col|
      attrs[col[:name]] = self.serialize_value col
    end
    attrs
  end

  def keys
    @result.column_names
  end

  # this is needed so that we can call defined_method outside of the subclass definition
  class << self
    public :define_method
  end

end