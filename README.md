# Multisert

Multisert is a buffer that handles bundling up INSERTs, which increases runtime
performance.

## Installation

Add this line to your application's Gemfile:

    gem 'multisert'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install multisert

## Usage

Let's start with a table:

```sql
CREATE TABLE IF NOT EXISTS some_database.some_table (
  field_1 int default null,
  field_2 int default null,
  field_3 int default null,
  field_4 int default null
);
```

Now let's say we want to insert 1,000,000 records after running the
current iterator through `some_magical_calculation` into our table from above.
Let's assume that `some_magical_calculation` takes a single integer input and
returns an array of 4 values.

```ruby
(0..1_000_000).each do |i|
  res = some_magical_calculation(i)
  dbclient.query %[
    INSERT INTO some_database.some_table (field_1, field_2, field_3, field_4)
    VALUES (#{res[0]}, #{res[1]}, #{res[2]}, #{res[3]})]
end
```

This works, but we can improve it's speed by bundling up inserts using
`Multisert`:

```ruby
buffer = Multisert.new connection: dbclient,
                       database:   'some_database',
                       table:      'some_table',
                       fields:     ['field_1', 'field_2', 'field_3', 'field_4']

(0..1_000_000).each do |i|
  res = some_magical_calculation(i)
  buffer << res
end
buffer.flush!
```

We start by creating a new Multisert instance, providing the database
connection, database and table, and fields as attributes. Next, as we get the
results from `some_magical_calculation`, we shovel each into the Multisert
instance. As we iterate through, the Multisert instance will build up the
records and then flush itself to the specified database table when it hits an
internal count (default is 10_000, but can be set via the `max_buffer_count`
attribute). One last thing to note is the `buffer.flush!` at the end of the
script. This ensures that any pending entries are written to the database table
that were not automatically taken care of by the auto-flush that will kick in
during the iteration.

## Performance

The gem has a quick performance test built in that can be run via:
```bash
$ ruby ./performance/multisert_performance_test
```
We ran the performance test (with some modification to iterate the test 5
times) and receive the following output:

```bash
$ ruby ./performance/multisert_performance_test.rb
# test 1:
#   insert w/o buffer took 53.37s to insert 100000 entries
#   multisert w/ buffer of 10000 took 1.77s to insert 100000 entries
#
# test 2:
#   insert w/o buffer took 53.22s to insert 100000 entries
#   multisert w/ buffer of 10000 took 1.84s to insert 100000 entries
#
# test 3:
#   insert w/o buffer took 54.42s to insert 100000 entries
#   multisert w/ buffer of 10000 took 1.9s to insert 100000 entries
#
# test 4:
#   insert w/o buffer took 53.38s to insert 100000 entries
#   multisert w/ buffer of 10000 took 1.81s to insert 100000 entries
#
# test 5:
#   insert w/o buffer took 53.52s to insert 100000 entries
#   multisert w/ buffer of 10000 took 1.78s to insert 100000 entries
```

As we can see, ~30x performance increase.

The performance test was run on a computer with the following specs:

    Model Name:             MacBook Air
    Model Identifier:       MacBookAir4,2
    Processor Name:         Intel Core i5
    Processor Speed:        1.7 GHz
    Number of Processors:   1
    Total Number of Cores:  2
    L2 Cache (per Core):    256 KB
    L3 Cache:               3 MB
    Memory:                 4 GB

## FAQ

### Packet Too Large / Connection Lost Errors

You may run into the "Packet Too Large" error when attempting to run a
multisert. This can comeback as this error explicitly or as a "Connection
Lost" error, depending on your mysql client.

To learn more, [read the documentation](http://dev.mysql.com/doc/refman/5.5/en//packet-too-large.html).

If you need to you can adjust the buffer size by setting `max_buffer_count`
attribute. Generally, 10,000 to 100,000 is a pretty good starting range.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
