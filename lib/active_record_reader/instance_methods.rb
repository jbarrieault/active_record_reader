module ActiveRecordReader
  # Select Methods
  SELECT_METHODS = [:select, :select_all, :select_one, :select_rows, :select_value, :select_values]

  # In case in the future we are forced to intercept connection#execute if the
  # above select methods are not sufficient
  #   SQL_READS = /\A\s*(SELECT|WITH|SHOW|CALL|EXPLAIN|DESCRIBE)/i

  module InstanceMethods
    SELECT_METHODS.each do |select_method|
      # Database Adapter method #exec_query is called for every select call
      # Replace #exec_query with one that calls the reader connection instead
      eval <<-METHOD
      def #{select_method}(sql, name = nil, *args)
        return super if active_record_reader_read_from_primary?

        ActiveRecordReader.read_from_primary do
          Reader.connection.#{select_method}(sql, "Reader: \#{name || 'SQL'}", *args)
        end
      end
      METHOD
    end

    # Returns whether to read from the primary database
    def active_record_reader_read_from_primary?
      # Read from primary when forced by thread variable, or
      # in a transaction and not ignoring transactions
      ActiveRecordReader.read_from_primary? ||
        (open_transactions > 0) && !ActiveRecordReader.ignore_transactions?
    end

  end
end

