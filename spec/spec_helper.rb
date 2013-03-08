module MultisertSpec
  class MrClean
    attr_accessor :connection, :database, :create_table_schemas

    def initialize attrs = {}
      @connection           = attrs[:connection]
      @database             = attrs[:database]
      @create_table_schemas = attrs[:create_table_schemas] || []
      yield self if block_given?
    end

    def ensure_clean_database! opts = {}
      clean_database! !!opts[:teardown_tables]
      ensure_tables!
    end

  private

    def database_exists?
      @connection.query('show databases').to_a.map { |database|
        database['Database']
      }.include?(@database)
    end

    def ensure_database!
      @connection.query "create database if not exists #{@database}"
    end

    def clean_database! teardown_tables
      return unless database_exists?
      @connection.query("show tables in #{@database}").to_a.each do |table|
        if teardown_tables
          @connection.query("drop table if exists #{@database}.#{table["Tables_in_#{@database}"]}")
        else
          @connection.query("truncate #{@database}.#{table["Tables_in_#{@database}"]}")
        end
      end
    end

    def ensure_tables!
      ensure_database!
      @create_table_schemas.each do |create_table_schema|
        @connection.query create_table_schema
      end
    end
  end
end
