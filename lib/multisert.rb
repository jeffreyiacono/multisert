class Multisert
  MAX_BUFFER_COUNT_DEFAULT = 10_000
  INSERT_OPERATION_DEFAULT = 'INSERT INTO'

  attr_accessor :connection,
                :database,
                :table,
                :fields,
                :insert_strategy

  attr_writer :max_buffer_count

  def initialize attrs = {}
    attrs.each do |attr, value|
      self.send "#{attr}=", value
    end
  end

  def fields
    @fields ||= []
  end

  def entries
    buffer
  end

  def << entry
    entries << entry
    write_buffer! if write_buffer?
    entry
  end

  def write_buffer!
    return if buffer_empty?
    @connection.query multisert_sql
    reset_buffer!
  end

  alias_method :write!, :write_buffer!
  alias_method :flush!, :write_buffer!

  def max_buffer_count
    @max_buffer_count || MAX_BUFFER_COUNT_DEFAULT
  end

  def with_buffering &block
    yield self
    write_buffer!
  end

private

  def insert_strategy?
    !!insert_strategy
  end

  def buffer
    @buffer ||= []
  end

  def reset_buffer!
    @buffer = []
  end

  def buffer_empty?
    buffer.empty?
  end

  def write_buffer?
    buffer.count >= max_buffer_count
  end

  def multisert_sql
    "#{multisert_preamble} #{multisert_values}"
  end

  def multisert_preamble
    "#{insert_operation} #{database}.#{table} (#{fields.join(',')}) VALUES"
  end

  def multisert_values
    @buffer.reduce([]) { |memo, entries|
      memo << "(#{entries.map { |e| cast e }.join(',')})"
      memo
    }.join(",")
  end

  def insert_operation
    return INSERT_OPERATION_DEFAULT unless insert_strategy?

    case insert_strategy.to_s.downcase
    when 'replace' then 'REPLACE INTO'
    when 'ignore'  then 'INSERT IGNORE'
    else raise "no operation for \"#{insert_strategy}\" insert strategy"
    end
  end

  def cast value
    case value
    # TODO: want to escape the string too, checking for " and ;
    when String then "'#{value}'"
    when Date   then "'#{value.strftime("%Y-%m-%d")}'"
    when Time   then "'#{value.strftime("%Y-%m-%d %H:%M:%S")}'"
    else value
    end
  end
end
