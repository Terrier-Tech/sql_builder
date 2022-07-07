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

  def test_object_arrays
    loc_count = SqlBuilder.new.select('count(*)').from('locations').exec.first.count

    res = SqlBuilder.new
        .select("json_agg(json_build_object('name', name, 'id', id)) as locs_json")
        .from('locations')
        .group_by('true')
        .exec
    assert 1, res.count
    row = res.first
    array = row.locs_json
    assert Array, array.class
    assert loc_count, array.count
    assert Hash, array.first.class
    assert '1', array.first['name']
  end


end