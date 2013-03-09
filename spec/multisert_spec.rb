require 'mysql2'
require './spec/spec_helper'
require './lib/multisert'

# TODO: allow overriding in yaml config
TEST_DATABASE = 'multisert_test'
TEST_TABLE    = 'test_data'

# TODO: make into yaml config
$connection = Mysql2::Client.new(host: 'localhost', username: 'root')

$cleaner = MultisertSpec::MrClean.new(database: TEST_DATABASE, connection: $connection) do |mgr|
  mgr.create_table_schemas << %[
    CREATE TABLE IF NOT EXISTS #{mgr.database}.#{TEST_TABLE} (
      test_field_int_1 int default null,
      test_field_int_2 int default null,
      test_field_int_3 int default null,
      test_field_int_4 int default null,
      test_field_varchar varchar(10) default null,
      test_field_date DATE default null,
      test_field_datetime DATETIME default null
    )]
end

describe Multisert do
  describe "<<" do
    let(:buffer) { described_class.new }

    it "addes to the entries" do
      buffer << [1, 2, 3]
      buffer.entries.should == [[1, 2, 3]]
    end

    it "calls #flush! when the number of entries equals (or exceeds) max buffer count" do
      buffer.max_buffer_count = 2
      buffer.should_receive(:flush!)
      buffer << [1, 2, 3]
      buffer << [1, 2, 3]
    end
  end

  describe "#flush!" do
    let(:connection) { $connection }
    let(:buffer) { described_class.new }

    before do
      $cleaner.ensure_clean_database! teardown_tables: (!!ENV['TEARDOWN'] || false)
    end

    it "does not fall over when there are no entries" do
      flush_records = connection.query "DELETE FROM #{TEST_DATABASE}.#{TEST_TABLE}"
      flush_records.to_a.should == []

      buffer.flush!

      flush_records = connection.query "SELECT * FROM #{TEST_DATABASE}.#{TEST_TABLE}"
      flush_records.to_a.should == []
      buffer.entries.should == []
    end

    it "multi-inserts all added entries" do
      pre_flush_records = connection.query "SELECT * FROM #{TEST_DATABASE}.#{TEST_TABLE}"
      pre_flush_records.to_a.should == []

      buffer.connection = connection
      buffer.database   = TEST_DATABASE
      buffer.table      = TEST_TABLE
      buffer.fields     = ['test_field_int_1',
                           'test_field_int_2',
                           'test_field_int_3',
                           'test_field_int_4']

      buffer << [ 1,  3,  4,  5]
      buffer << [ 6,  7,  8,  9]
      buffer << [10, 11, 12, 13]
      buffer << [14, 15, 16, 17]

      buffer.flush!

      post_flush_records = connection.query %[
        SELECT
            test_field_int_1
          , test_field_int_2
          , test_field_int_3
          , test_field_int_4
        FROM #{TEST_DATABASE}.#{TEST_TABLE}]

      post_flush_records.to_a.should == [
        {'test_field_int_1' => 1,  'test_field_int_2' => 3,  'test_field_int_3' => 4,  'test_field_int_4' => 5},
        {'test_field_int_1' => 6,  'test_field_int_2' => 7,  'test_field_int_3' => 8,  'test_field_int_4' => 9},
        {'test_field_int_1' => 10, 'test_field_int_2' => 11, 'test_field_int_3' => 12, 'test_field_int_4' => 13},
        {'test_field_int_1' => 14, 'test_field_int_2' => 15, 'test_field_int_3' => 16, 'test_field_int_4' => 17}]

      buffer.entries.should == []
    end

    it "works with strings" do
      pre_flush_records = connection.query "SELECT * FROM #{TEST_DATABASE}.#{TEST_TABLE}"
      pre_flush_records.to_a.should == []

      buffer.connection = connection
      buffer.database   = TEST_DATABASE
      buffer.table      = TEST_TABLE
      buffer.fields     = ['test_field_varchar']

      buffer << ['a']
      buffer << ['b']
      buffer << ['c']
      buffer << ['d']

      buffer.flush!

      post_flush_records = connection.query %[SELECT test_field_varchar FROM #{TEST_DATABASE}.#{TEST_TABLE}]
      post_flush_records.to_a.should == [
        {'test_field_varchar' => 'a'},
        {'test_field_varchar' => 'b'},
        {'test_field_varchar' => 'c'},
        {'test_field_varchar' => 'd'}]

      buffer.entries.should == []
    end

    it "works with strings that have illegal characters"

    it "works with dates" do
      pre_flush_records = connection.query "SELECT * FROM #{TEST_DATABASE}.#{TEST_TABLE}"
      pre_flush_records.to_a.should == []

      buffer.connection = connection
      buffer.database   = TEST_DATABASE
      buffer.table      = TEST_TABLE
      buffer.fields     = ['test_field_date']

      buffer << [Date.new(2013, 1, 15)]
      buffer << [Date.new(2013, 1, 16)]
      buffer << [Date.new(2013, 1, 17)]
      buffer << [Date.new(2013, 1, 18)]

      buffer.flush!

      post_flush_records = connection.query %[SELECT test_field_date FROM #{TEST_DATABASE}.#{TEST_TABLE}]

      post_flush_records.to_a.should == [
        {'test_field_date' => Date.parse('2013-01-15')},
        {'test_field_date' => Date.parse('2013-01-16')},
        {'test_field_date' => Date.parse('2013-01-17')},
        {'test_field_date' => Date.parse('2013-01-18')}]

      buffer.entries.should == []
    end

    it "works with times" do
      pre_flush_records = connection.query "SELECT * FROM #{TEST_DATABASE}.#{TEST_TABLE}"
      pre_flush_records.to_a.should == []

      buffer.connection = connection
      buffer.database   = TEST_DATABASE
      buffer.table      = TEST_TABLE
      buffer.fields     = ['test_field_datetime']

      buffer << [Time.new(2013, 1, 15, 1, 5, 11)]
      buffer << [Time.new(2013, 1, 16, 2, 6, 22)]
      buffer << [Time.new(2013, 1, 17, 3, 7, 33)]
      buffer << [Time.new(2013, 1, 18, 4, 8, 44)]

      buffer.flush!

      post_flush_records = connection.query %[SELECT test_field_datetime FROM #{TEST_DATABASE}.#{TEST_TABLE}]

      post_flush_records.to_a.should == [
        {'test_field_datetime' => Time.new(2013, 1, 15, 1, 5, 11)},
        {'test_field_datetime' => Time.new(2013, 1, 16, 2, 6, 22)},
        {'test_field_datetime' => Time.new(2013, 1, 17, 3, 7, 33)},
        {'test_field_datetime' => Time.new(2013, 1, 18, 4, 8, 44)}]

      buffer.entries.should == []
    end
  end
end
