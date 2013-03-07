require './performance/performance_helper'

PERFORMANCE_DATABASE    = 'multisert_performance'
PERFORMANCE_TABLE       = 'performance_data'
PERFORMANCE_DESTINATION = "#{PERFORMANCE_DATABASE}.#{PERFORMANCE_TABLE}"
NUM_OF_OPERATIONS       = 100_000
CONNECTION              = Mysql2::Client.new(host: 'localhost', username: 'root')

def puts_with_time content
  puts "[#{Time.now}] #{content}"
end

def generate_records records_count = NUM_OF_OPERATIONS
  puts_with_time "generating #{records_count} random entries"
  sample_records = (0...records_count).reduce([]) do |memo, i|
    memo << {'test_field_1' => i,
             'test_field_2' => i + 1,
             'test_field_3' => i + 2,
             'test_field_4' => i + 3}
    memo
  end
  puts_with_time "generated #{records_count} random entries"
  sample_records
end

def ensure_data_completeness! connection, datastore, expected_count
  unless (res = connection.query("SELECT COUNT(*) AS the_count FROM #{datastore}").to_a.first['the_count']) == expected_count
    raise RuntimeError, "data not written completely. Got #{res}, expected #{expected_count}"
  end
end

def insert_performance_test connection, cleaner, sample_records, destination
  fields = sample_records.first.keys.join(', ')

  cleaner.ensure_clean_database!

  (timer = Timer.new).start!
  sample_records.each do |record|
    connection.query %[
      INSERT INTO #{destination} (#{fields})
      VALUES (#{record.map { |k,v| v }.join(', ')})]
  end
  runtime = timer.stop!
  ensure_data_completeness! connection, destination, sample_records.count
  puts "insert w/o buffer took #{runtime.round(2)}s to insert #{sample_records.count} entries"
end

def multinsert_performance_test connection, cleaner, sample_records, destination, max_buffer_count = nil
  database, table = destination.split('.')

  buffer = Multisert.new connection:       connection,
                         database:         database,
                         table:            table,
                         fields:           sample_records.first.keys,
                         max_buffer_count: max_buffer_count

  cleaner.ensure_clean_database!

  (timer = Timer.new).start!
  sample_records.each do |record|
    buffer << record.map { |k, v| v }
  end
  buffer.flush!
  runtime = timer.stop!
  ensure_data_completeness! connection, destination, sample_records.count
  puts "multisert w/ buffer of #{buffer.max_buffer_count} took #{runtime.round(2)}s to insert #{sample_records.count} entries"
end

cleaner = MrClean.new(database: PERFORMANCE_DATABASE, connection: CONNECTION)
cleaner.create_table_schemas << %[
  CREATE TABLE IF NOT EXISTS #{PERFORMANCE_DATABASE}.#{PERFORMANCE_TABLE} (
      test_field_1 int default null
    , test_field_2 int default null
    , test_field_3 int default null
    , test_field_4 int default null
  )]

sample_records = generate_records

puts_with_time "starting performance test: using #{sample_records.count} random entries, writing to #{PERFORMANCE_DESTINATION}"

insert_performance_test     CONNECTION, cleaner, sample_records, PERFORMANCE_DESTINATION
multinsert_performance_test CONNECTION, cleaner, sample_records, PERFORMANCE_DESTINATION,  10_000
