require 'mysql2'
require './spec/spec_helper'
require './lib/multisert'

# TODO: allow overriding in yaml config
TEST_DATABASE      = 'multisert_test'
TEST_TABLE         = 'test_data'
TEST_INDEXED_TABLE = 'test_indexed_data'

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
      test_field_datetime DATETIME default null)]

  mgr.create_table_schemas << %[
    CREATE TABLE IF NOT EXISTS #{mgr.database}.#{TEST_INDEXED_TABLE} (
      test_id int not null,
      test_field varchar(15) default null,
      primary key (test_id))]
end

describe Multisert do
  describe "<<" do
    let(:buffer) { described_class.new }

    it "addes to the entries" do
      buffer << [1, 2, 3]
      expect(buffer.entries).to eq [[1, 2, 3]]
    end

    it "calls #flush! when the number of entries equals (or exceeds) max buffer count" do
      buffer.max_buffer_count = 2
      buffer.should_receive(:write_buffer!)
      buffer << [1, 2, 3]
      buffer << [1, 2, 3]
    end
  end

  describe "#write_buffer!" do
    let(:connection) { $connection }
    let(:buffer) { described_class.new }

    before do
      $cleaner.ensure_clean_database! teardown_tables: (!!ENV['TEARDOWN'] || false)
    end

    it "does not fall over when there are no entries" do
      connection.query "DELETE FROM #{TEST_DATABASE}.#{TEST_TABLE}"

      buffer.write_buffer!

      write_buffer_records = connection.query "SELECT * FROM #{TEST_DATABASE}.#{TEST_TABLE}"
      expect(write_buffer_records.to_a).to eq []
      expect(buffer.entries).to eq []
    end

    it "multi-inserts all added entries and clears #entries" do
      pre_write_buffer_records = connection.query "SELECT * FROM #{TEST_DATABASE}.#{TEST_TABLE}"
      expect(pre_write_buffer_records.to_a).to eq []

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

      buffer.write_buffer!

      post_write_buffer_records = connection.query %[
        SELECT
            test_field_int_1
          , test_field_int_2
          , test_field_int_3
          , test_field_int_4
        FROM #{TEST_DATABASE}.#{TEST_TABLE}]

      expect(post_write_buffer_records.to_a).to eq [
        {'test_field_int_1' => 1,  'test_field_int_2' => 3,  'test_field_int_3' => 4,  'test_field_int_4' => 5},
        {'test_field_int_1' => 6,  'test_field_int_2' => 7,  'test_field_int_3' => 8,  'test_field_int_4' => 9},
        {'test_field_int_1' => 10, 'test_field_int_2' => 11, 'test_field_int_3' => 12, 'test_field_int_4' => 13},
        {'test_field_int_1' => 14, 'test_field_int_2' => 15, 'test_field_int_3' => 16, 'test_field_int_4' => 17}]

      expect(buffer.entries).to eq []
    end

    it "works with strings" do
      pre_write_buffer_records = connection.query "SELECT * FROM #{TEST_DATABASE}.#{TEST_TABLE}"
      expect(pre_write_buffer_records.to_a).to eq []

      buffer.connection = connection
      buffer.database   = TEST_DATABASE
      buffer.table      = TEST_TABLE
      buffer.fields     = ['test_field_varchar']

      buffer << ['a']
      buffer << ['b']
      buffer << ['c']
      buffer << ['d']

      buffer.write_buffer!

      post_write_buffer_records = connection.query %[SELECT test_field_varchar FROM #{TEST_DATABASE}.#{TEST_TABLE}]
      expect(post_write_buffer_records.to_a).to eq [
        {'test_field_varchar' => 'a'},
        {'test_field_varchar' => 'b'},
        {'test_field_varchar' => 'c'},
        {'test_field_varchar' => 'd'}]

      expect(buffer.entries).to eq []
    end

    it "works with strings that have illegal characters"

    it "works with dates" do
      pre_write_buffer_records = connection.query "SELECT * FROM #{TEST_DATABASE}.#{TEST_TABLE}"
      expect(pre_write_buffer_records.to_a).to eq []

      buffer.connection = connection
      buffer.database   = TEST_DATABASE
      buffer.table      = TEST_TABLE
      buffer.fields     = ['test_field_date']

      buffer << [Date.new(2013, 1, 15)]
      buffer << [Date.new(2013, 1, 16)]
      buffer << [Date.new(2013, 1, 17)]
      buffer << [Date.new(2013, 1, 18)]

      buffer.write_buffer!

      post_write_buffer_records = connection.query %[SELECT test_field_date FROM #{TEST_DATABASE}.#{TEST_TABLE}]

      expect(post_write_buffer_records.to_a).to eq [
        {'test_field_date' => Date.parse('2013-01-15')},
        {'test_field_date' => Date.parse('2013-01-16')},
        {'test_field_date' => Date.parse('2013-01-17')},
        {'test_field_date' => Date.parse('2013-01-18')}]

      expect(buffer.entries).to eq []
    end

    it "works with times" do
      pre_write_buffer_records = connection.query "SELECT * FROM #{TEST_DATABASE}.#{TEST_TABLE}"
      expect(pre_write_buffer_records.to_a).to eq []

      buffer.connection = connection
      buffer.database   = TEST_DATABASE
      buffer.table      = TEST_TABLE
      buffer.fields     = ['test_field_datetime']

      buffer << [Time.new(2013, 1, 15, 1, 5, 11)]
      buffer << [Time.new(2013, 1, 16, 2, 6, 22)]
      buffer << [Time.new(2013, 1, 17, 3, 7, 33)]
      buffer << [Time.new(2013, 1, 18, 4, 8, 44)]

      buffer.write_buffer!

      post_write_buffer_records = connection.query %[SELECT test_field_datetime FROM #{TEST_DATABASE}.#{TEST_TABLE}]

      expect(post_write_buffer_records.to_a).to eq [
        {'test_field_datetime' => Time.new(2013, 1, 15, 1, 5, 11)},
        {'test_field_datetime' => Time.new(2013, 1, 16, 2, 6, 22)},
        {'test_field_datetime' => Time.new(2013, 1, 17, 3, 7, 33)},
        {'test_field_datetime' => Time.new(2013, 1, 18, 4, 8, 44)}]

      expect(buffer.entries).to eq []
    end
  end

  describe "#flush!" do
    it "aliases #write_buffer!" do
      instance = described_class.new
      flush_method = instance.method(:flush!)
      expect(flush_method).to eq instance.method(:write_buffer!)
    end
  end

  describe "#write!" do
    it "aliases #write_buffer!" do
      instance = described_class.new
      flush_method = instance.method(:write!)
      expect(flush_method).to eq instance.method(:write_buffer!)
    end
  end

  describe "#insert_strategy" do
    let(:connection) { $connection }
    let(:buffer) { described_class.new }

    before do
      $cleaner.ensure_clean_database! teardown_tables: (!!ENV['TEARDOWN'] || false)
    end

    context "set to replace" do
      it "writes over an existing record with the same primary / unique key" do
        connection.query %[INSERT INTO #{TEST_DATABASE}.#{TEST_INDEXED_TABLE} (test_id, test_field)
                           VALUES (1, 'ONE'), (2, 'TWO')]

        buffer.connection      = connection
        buffer.database        = TEST_DATABASE
        buffer.table           = TEST_INDEXED_TABLE
        buffer.fields          = ['test_id', 'test_field']
        buffer.insert_strategy = :replace

        buffer << [1, 'SOMETHING NEW']

        buffer.write_buffer!

        post_write_buffer_records = connection.query %[
          SELECT
              test_id
            , test_field
          FROM #{TEST_DATABASE}.#{TEST_INDEXED_TABLE}]

        expect(post_write_buffer_records.to_a).to eq [
          {'test_id' => 1, 'test_field' => 'SOMETHING NEW'},
          {'test_id' => 2, 'test_field' => 'TWO'}]
      end
    end

    context "set to ignore" do
      before do
        connection.query %[INSERT INTO #{TEST_DATABASE}.#{TEST_INDEXED_TABLE} (test_id, test_field)
                           VALUES (1, 'ONE'), (2, 'TWO')]

        buffer.connection      = connection
        buffer.database        = TEST_DATABASE
        buffer.table           = TEST_INDEXED_TABLE
        buffer.fields          = ['test_id', 'test_field']
        buffer.insert_strategy = :ignore

        buffer << [1, 'NEW']
        buffer << [3, 'ALSO NEW']
      end

      it "does not raise an error" do
        expect { buffer.write_buffer! }.to_not raise_error
      end

      it "writes over an existing record with the same primary / unique key" do
        buffer.write_buffer!

        post_write_buffer_records = connection.query %[
          SELECT
              test_id
            , test_field
          FROM #{TEST_DATABASE}.#{TEST_INDEXED_TABLE}]

        expect(post_write_buffer_records.to_a).to eq [
          {'test_id' => 1, 'test_field' => 'ONE'},
          {'test_id' => 2, 'test_field' => 'TWO'},
          {'test_id' => 3, 'test_field' => 'ALSO NEW'}]
      end
    end

    context "set to non-supported insert strategy" do
      it "tells of an error" do
        buffer.connection      = connection
        buffer.database        = TEST_DATABASE
        buffer.table           = TEST_INDEXED_TABLE
        buffer.fields          = ['test_id', 'test_field']
        buffer.insert_strategy = :some_bogus_operation

        buffer << [1, 'NEW']

        expect { buffer.write_buffer! }.to raise_error
      end
    end
  end
end
