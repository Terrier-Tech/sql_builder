require "test_helper"

class WhereSyntaxTest < Minitest::Test
  # String
  def test_where_syntax_string
    query = SqlBuilder.new
                      .select(%w(id display_name created_at))
                      .from('locations')
                      .where("name=? and location=?", "foo", "bar")
    sql = query.to_sql
    assert sql.downcase =~ /select\s+id, display_name, created_at from locations\s+where\s+\(name='foo' and location='bar'\)/
  end

  #Time
  def test_where_syntax_time
    query = SqlBuilder.new
                      .select(%w(id display_name created_at))
                      .from('locations')
                      .where("date=?", "12:12:12 01-02-2020")
    sql = query.to_sql
    assert sql.downcase =~ /select\s+id, display_name, created_at from locations\s+where\s+\(date='12:12:12 01-02-2020'\)/
  end

  # Array
  # ex: .where("status in ?",   ['action', 'complete'])
  #   => "status in ('action', 'complete')"
  def test_where_syntax_array
    query = SqlBuilder.new
                      .select(%w(id display_name created_at))
                      .from('locations')
                      .where("name=? and state in ? and id=?","terrier", ["foo","bar"], 1)
    sql = query.to_sql
    assert sql.downcase =~ /select\s+id, display_name, created_at from locations\s+where\s+\(name='terrier' and state in \('foo','bar'\) and id=1\)/
  end

  # Number
  def test_where_syntax_number
    query = SqlBuilder.new
                      .select(%w(id display_name created_at))
                      .from('locations')
                      .where("id=?", 123.4)
    sql = query.to_sql
    assert sql.downcase =~ /select\s+id, display_name, created_at from locations\s+where\s+\(id=123.4\)/
  end

  # Exists
  def test_where_exists
    subquery = SqlBuilder.new
      .select('id')
      .from('users', 'subordinate')
      .where('subordinate.reports_to_id = manager.id')
      .limit(nil)
    query = SqlBuilder.new
      .select(%w[id first_name last_name])
      .from('users', 'manager')
      .exists(subquery)
      .limit(nil)
    sql = query.to_sql
    assert_equal sql.downcase.squish, "select id, first_name, last_name from users as manager where (exists ( select id from users as subordinate where (subordinate.reports_to_id = manager.id)))"

  end
end