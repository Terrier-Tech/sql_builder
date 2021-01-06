require "test_helper"

class SqlBuilderTest < Minitest::Test
    # Bobby Tables Control
    def test_sanitization_control
        payload = "Robert'; DROP TABLE Locations;" #pwned

        query = SqlBuilder.new
                          .select(%w(id display_name created_at))
                          .from('locations')
                          .where("name='#{payload}'")
        sql = query.to_sql
        assert sql.downcase =~ /select\s+id, display_name, created_at from locations\s+where\s+\(name='robert'; drop table locations;'\)/
    end

    # Bobby Tables?
    def test_bobby_tables
        payload = "Robert'; DROP TABLE locations;" #pwned?

        query = SqlBuilder.new
        .select(%w(id display_name created_at))
        .from('locations')
        .where("name=? or id=?", payload, 1234)
        sql = query.to_sql
        assert sql.downcase =~ /select\s+id, display_name, created_at from locations\s+where\s+\(name='robert''; drop table locations;' or id=1234\)/
    end

    def test_escape_percent_symbol
        query = SqlBuilder.new
                          .select(%w(id display_name created_at))
                          .from('locations')
                          .where("payment.created_by_name ilike '%portal%' OR u.role = 'customer'")
        sql = query.to_sql
        assert sql.downcase =~ /select\s+id, display_name, created_at from locations\s+where\s+\(payment.created_by_name ilike '%portal%' or u.role = 'customer'\)/
    end
end