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

end
