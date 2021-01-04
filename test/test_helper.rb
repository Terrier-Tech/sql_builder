$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
require "sql_builder"
require "minitest/autorun"
require "active_record"

class Minitest::Test
  # Config
  db_config       = YAML::load(File.open('test/config/database.yml'))
  db_config_admin = db_config.merge({'database' => 'postgres', 'schema_search_path' => 'public'})

  # Delete DB
  ActiveRecord::Base.establish_connection(db_config_admin)
  ActiveRecord::Base.connection.drop_database(db_config["database"])
  puts "Database deleted."

  # Create DB
  ActiveRecord::Base.establish_connection(db_config_admin)
  ActiveRecord::Base.connection.create_database(db_config["database"])
  puts "Database created."

  # Populate DB
  ActiveRecord::Base.establish_connection(db_config)
  create_table = 'CREATE TABLE locations ( id int primary key, name text)'
  ActiveRecord::Base.connection.execute(create_table)
  0.upto(100) do |i|
    ActiveRecord::Base.connection.execute("INSERT INTO locations (id, name) VALUES (#{i}, 'location_#{i}');")
  end
  puts "Database populated."
end
