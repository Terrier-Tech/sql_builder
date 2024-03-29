# SqlBuilder

SqlBuilder is a small, simple Ruby library that lets you compose SQL queries using a fluent, builder syntax.

This is *not* an ORM and does require any schema definition or mapping. 
You simply specify a query and SqlBuilder will generate an ad-hoc, read-only Ruby class to represent the result.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sql_builder', git: 'git@github.com:Terrier-Tech/sql_builder.git'
```

And then execute:

    $ bundle

## Usage

SqlBuilder uses a chainable builder syntax to make constructing queries more flexible than using plain strings. 
It also automatically handles things like applying prefixes to column names and managing aliases.

```ruby
# sql builder example
locs = SqlBuilder.new
  .select(%w(city state), 'loc', 'location_') # columns, table alias, prefix
  .select(%w(first_name last_name), 'tech', 'technician_') 
  .from('locations', 'loc') # table name, alias
  .left_join('users', 'tech', 'tech.id = loc.primary_technician_id') # table name, alias, clause
  .where("loc.zip = ?", '55124') # plain string clause
  .where("tech.first_name = ?", 'Billy')
  .exec

# returns an array of POROs with attributes location_city, location_state, 
# technician_first_name, technician_last_name
locs.each do |loc|
  puts "#{loc.technician_first_name} in #{loc.location_city}" 
end
```

Attribute types will be automatically inferred from the names, including converting from cents to dollars.

Since SqlBuilder stores all of the components of the query and is a plain Ruby object, it can also be composed conditionally:

```ruby
builder = SqlBuilder.new
  .select(%w(first_name last_name), 'tech')
  .from('users', 'tech')
  .where('tech._state = 0')
  .where("tech.role = ?", 'technician')

if branch_id
  builder.where("tech.branch_id = ?", branch_id)
end

techs = builder.exec
```


### Important Notes

First, **SqlBuilder now sanitizes input!**, this utilizes ActiveRecord's(v4.2) ```sanitize_sql_array``` method to do the heavy lifting. You may opt for a more recent version of ActiveRecord in which case it will use the ```sanitize``` method.

Second, SqlBuilder assumes you have ActiveRecord around in order to use `SqlBuilder#exec`.
If this isn't the case, you can always get the raw SQL using `SqlBuilder#to_sql`. 

### Joins

SqlBuilder offers 4 join commands `left_join`, `inner_join`, `outer_join`, and `right_join`.  Any of these can take one of three combinations of arguments (all strings):

```ruby
# base_query
inspection_items = SqlBuilder.new
    .select('inspection_items.*')
    
# the following three examples will add the following join clause: INNER JOIN work_orders AS wo ON wo.id = inspection_items.work_order_id
# three args can be used to add any join (parent or child)
inspection_items.inner_join('work_orders', 'wo', 'wo.id = inspection_items.work_order_id')

# two args can only be used to add a parent table join
inspection_items.inner_join('work_orders AS wo', 'inspection_items.work_order_id')

# one arg can only be used to add a parent table join
inspection_items.inner_join('work_orders AS wo')


# note that the 2 arg variation can be used to join a table that does not have a traditional foreign_key
work_orders = SqlBuilder.new
    .select('work_orders.*')

work_orders.inner_join('users', 'work_orders.technician_id')
```


### Computed Columns

You can compute additional columns on the result set. 
Use the `compute_column` method with the name of the new column and a block that accepts each row: 

```ruby
locs.compute_column 'age' do |row|
  Time.now - row.created_at
end
```

Alternatively, you can use `compute_columns` to compute multiple columns at once: 

```ruby
locs.compute_columns do |row|
  geo = row.geo.parse_geo_point
  {latitude: geo.latitude, longitude: geo.longitude}
end
```

### as_raw

Optionally, you can call the `as_raw' method on a SqlBuilder instance to have it return hashes instead of objects as the result: 

```ruby
locs = SqlBuilder.new
  .select(%w(city state), 'loc', 'location_')
  .select(%w(first_name last_name), 'tech', 'technician_') 
  .from('locations')
  .inner_join('users', 'tech', 'tech.id = loc.primary_technician_id')
  .where("zip = ?", '55124')
  .as_raw
  .exec

locs.each do |loc|
  puts "#{loc['technician_first_name']} in #{loc['location_city']}"
end
```

NOTE: for historical reasons, `.as_raw` is enabled by default in Clypboard. Use `.as_objects` to enable the Ruby object generation.

### Dialects

Currently, SqlBuilder only supports PostgresQL and MS-SQL dialects.
You can set the dialect by calling `SqlBuilder#dialect` with either `:psql` (default) or `mssql`.


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Terrier-Tech/sql_builder. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
