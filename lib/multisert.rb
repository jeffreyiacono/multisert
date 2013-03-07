class Multisert
  MAX_BUFFER_COUNT_DEFAULT = 10_000

  attr_accessor :connection
  attr_accessor :database
  attr_accessor :table
  attr_accessor :fields
  attr_writer   :max_buffer_count

  def initialize attrs = {}
    attrs.each do |attr, value|
      self.send "#{attr}=", value
    end
  end

  def fields
    @fields ||= []
  end

  def entries
    @entries ||= []
  end

  def << entry
    entries << entry
    flush! if flush_buffer?
    entry
  end

  def flush!
    return if buffer_empty?
    @connection.query multisert_sql
    reset_entries!
  end

  def max_buffer_count
    @max_buffer_count || MAX_BUFFER_COUNT_DEFAULT
  end

private

  def buffer_empty?
    entries.empty?
  end

  def flush_buffer?
    entries.count >= max_buffer_count
  end

  def reset_entries!
    @entries = []
  end

  def multisert_sql
    "#{multisert_preamble} #{multisert_values}"
  end

  def multisert_preamble
    "INSERT INTO #{database}.#{table} (#{fields.join(',')}) VALUES"
  end

  def multisert_values
    @entries.reduce([]) { |memo, entries|
      memo << "(#{entries.map { |e| cast e }.join(',')})"
      memo
    }.join(",")
  end

  def cast value
    case value
    when String
      # TODO: want to escape the string too, checking for " and ;
      "'#{value}'"
    when Date
      "'#{value}'"
    else
      value
    end
  end
end
