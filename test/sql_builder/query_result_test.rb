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
        .group_by("substring(name, 0, 1)")
        .exec
    assert 1, res.count
    row = res.first
    array = row.locs_json
    assert Array, array.class
    assert loc_count, array.count
    assert Hash, array.first.class
    assert '1', array.first['name']
  end

  def test_pluck_with_single_string_argument
    assert_equal [0, 1], SqlBuilder.new.select("*").from("locations").order_by("id").limit(2).as_objects.exec.pluck("id")
  end

  def test_pluck_with_single_symbol_argument
    assert_equal [0, 1], SqlBuilder.new.select("*").from("locations").order_by("id").limit(2).as_objects.exec.pluck(:id)
  end

  def test_pluck_with_multiple_arguments
    assert_equal [[0, "location_0"], [1, "location_1"]], SqlBuilder.new.select("*").from("locations").order_by("id").limit(2).as_objects.exec.pluck(:id, :name)
  end
end