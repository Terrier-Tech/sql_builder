require "test_helper"

class SqlBuilderTest < Minitest::Test

    #== string
    def test_sanitize_string
        #clean
        branch = "Robert; DROP TABLE Locations;"
        location = "bang"

        query = SqlBuilder.new
        .select(%w(id display_name created_at))
        .from('locations')
        .where("branch_id=? or location_id=?", branch, location)
        sql = query.to_sql
        puts sql.downcase
        assert sql.downcase =~ /select\s+id, display_name, created_at from locations/ #TODO fix expected output

        #injection

    end

end