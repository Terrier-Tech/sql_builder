require "test_helper"

class SqlBuilderTest < Minitest::Test

    #== string
    def test_sanitize_string
        #clean
        branch = 1
        location = 2

        query = SqlBuilder.new
        .select(%w(id display_name created_at))
        .from('locations')
        .where("branch_id=? or location_id=?", branch, location)
        sql = query.to_sql
        assert sql.downcase =~ /select\s+id, display_name, created_at from locations/ #TODO fix expected output

        #injection
        
    end

    #== time
    def test_sanitize_time
        query = SqlBuilder.new
                .select(%w(id display_name created_at))
                .from('locations')
                .where("created_at > '2010-01-01'")

        sql = query.to_sql
        assert sql.downcase =~ /select\s+id, display_name, created_at from locations/
    end

    #== array

    #== number

end