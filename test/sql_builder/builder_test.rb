require "test_helper"

class SqlBuilderTest < Minitest::Test

  def test_basic
    query = SqlBuilder.new
          .select(%w(id display_name created_at))
          .from('locations')
          .where("created_at > '2010-01-01'")

    sql = query.to_sql
    assert sql.downcase =~ /select\s+id, display_name, created_at from locations/
  end

  def test_type_hints
    # res = SqlBuilder.new
    #     .select('data')
    #     .from('locations')
    #     .exec
    # res.set_column_type 'data', :json
  end

  def test_mssql_dialect
    limit = 100

    builder = SqlBuilder.new
                  .dialect(:mssql)
                  .select('*')
                  .from('locations')
                  .limit(limit)

    assert_equal :mssql, builder.dialect

    query = builder.to_sql
    assert query.index("SELECT TOP #{limit}")
    assert !query.index("LIMIT #{limit}")

    query = builder.dialect(:psql).to_sql
    assert !query.index("SELECT TOP #{limit}")
    assert query.index("LIMIT #{limit}")
  end

  def test_result_limit_check
    query = SqlBuilder.new
                      .select(%w(id))
                      .from('locations')
                      .where("id=? or id=? or id=?", 1, 2, 3)
                      .limit(3)

    err = assert_raises(RuntimeError) { query.exec }
    assert_match /Query result has exactly 3 results, which is the same as the Limit 3/, err.message
  end

end
