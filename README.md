# Multisert

Multisert is a buffer that handles bundling up INSERTs, which increases runtime
performance.

## Installation

To install, this line to should be added to the application's Gemfile:

    gem 'multisert'

And then the following should be executed:

    $ bundle

Alternatively, this can be installed by executing:

    $ gem install multisert

## Usage

As an example:

There is a table, defined below, into which records will be inserted:

```sql
CREATE TABLE IF NOT EXISTS some_database.some_table (
  field_1 int default null,
  field_2 int default null,
  field_3 int default null,
  field_4 int default null
);
```

The goal is to insert 1,000,000 records after running the
current iterator through `some_magical_calculation` into the table above.
The `some_magical_calculation` takes a single integer input and
returns an array of 4 values.

```ruby
(0..1_000_000).each do |i|
  res = some_magical_calculation(i)
  dbclient.query %[
    INSERT INTO some_database.some_table (field_1, field_2, field_3, field_4)
    VALUES (#{res[0]}, #{res[1]}, #{res[2]}, #{res[3]})]
end
```

While this works, it can optimized for faster query performance by bundling the inserts using `Multisert`:

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

To create a new Multisert instance one must provide the database connection, database and table, and fields as attributes. As values are returned from `some_magical_calculation`, they are shoveled into the Multisert instance. As the process iterates, the Multisert instance will build up the records and then flush itself to the specified database table when it hits an internal count. (Note: the default count is 10_000, but the value can be changed by setting the `max_buffer_count` attribute). The last item of note is the `buffer.flush!` at the end of the script. This ensures that any pending entries that escaped the auto-flush during the iteration will be written to the database table.

## Performance

The gem has a quick, built-in performance test that can be run via:
```bash
$ ruby ./performance/multisert_performance_test
```
The following reflects the output a recent performance test (with some modification to iterate the test 5
times)::

```bash
$ ruby ./performance/multisert_performance_test
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

As evident in the test results above, a ~30x performance increase was observed!

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

It's possible that one will encounter the "Packet Too Large" error when attempting to run a multisert. This can be flagged by this error explicitly or as a "Connection Lost" error, depending on your MySql client.

To learn more, [read the documentation](http://dev.mysql.com/doc/refman/5.5/en//packet-too-large.html).

To adjust the buffer size, set the `max_buffer_count`
attribute. Generally, 10,000 to 100,000 is a pretty good starting range.

## Contributing

1. Fork it
2. Create a feature branch (`git checkout -b my-new-feature`)
3. Commit the changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

Copyright 2013 Jeff Iacono

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
