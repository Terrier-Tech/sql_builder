require "test_helper"

class QueryResultTest < Minitest::Test

  def test_arrays
    res = SqlBuilder.new
        .select("('one','two','three') as an_array")
        .exec
    assert 1, res.count
    row = res.first
    assert Array, row.an_array.class
    assert 3, row.an_array.count
    assert 'one', row.an_array.first
  end


end