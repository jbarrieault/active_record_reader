#
# ActiveRecord read from a reader
#
module ActiveRecordReader

  # Install ActiveRecord::Reader into ActiveRecord to redirect reads to the reader
  # Parameters:
  #   adapter_class:
  #     By default, only the default Database adapter (ActiveRecord::Base.connection.class)
  #     is extended with reader read capabilities
  #
  #   environment:
  #     In a non-Rails environment, supply the environment such as
  #     'development', 'production'
  def self.install!(adapter_class = nil, environment = nil)
    reader_config =
      if ActiveRecord::Base.connection.respond_to?(:config)
        ActiveRecord::Base.connection.config[:reader]
      else
        ActiveRecord::Base.configurations[environment || Rails.env]['reader']
      end
    if reader_config
      ActiveRecord::Base.logger.info "ActiveRecordReader.install! v#{ActiveRecordReader::VERSION} Establishing connection to reader database"
      Reader.establish_connection(reader_config)

      # Inject a new #select method into the ActiveRecord Database adapter
      base = adapter_class || ActiveRecord::Base.connection.class
      base.send(:include, InstanceMethods)
    else
      ActiveRecord::Base.logger.info "ActiveRecordReader not installed since no reader database defined"
    end
  end

  # Force reads for the supplied block to read from the primary database
  # Only applies to calls made within the current thread
  def self.read_from_primary
    return yield if read_from_primary?
    begin
      # Set :primary indicator in thread local storage so that it is visible
      # during the select call
      read_from_primary!
      yield
    ensure
      read_from_reader!
    end
  end

  #
  # The default behavior can also set to read/write operations against primary
  # Create an initializer file config/initializer/active_record_reader.rb
  # and set ActiveRecordReader.read_from_primary! to force read from primary.
  # Then use this method and supply block to read from the reader database
  # Only applies to calls made within the current thread
  def self.read_from_reader
    return yield if read_from_reader?
    begin
      # Set nil indicator in thread local storage so that it is visible
      # during the select call
      read_from_reader!
      yield
    ensure
      read_from_primary!
    end
  end

  # Whether this thread is currently forcing all reads to go against the primary database
  def self.read_from_primary?
    thread_variable_get(:active_record_reader) == :primary
  end

  # Whether this thread is currently forcing all reads to go against the reader database
  def self.read_from_reader?
    thread_variable_get(:active_record_reader) == nil
  end

  # Force all subsequent reads on this thread and any fibers called by this thread to go the primary
  def self.read_from_primary!
    thread_variable_set(:active_record_reader, :primary)
  end

  # Subsequent reads on this thread and any fibers called by this thread can go to a reader
  def self.read_from_reader!
    thread_variable_set(:active_record_reader, nil)
  end

  # Returns whether reader reads are ignoring transactions
  def self.ignore_transactions?
    @ignore_transactions
  end

  # Set whether reader reads should ignore transactions
  def self.ignore_transactions=(ignore_transactions)
    @ignore_transactions = ignore_transactions
  end

  ##############################################################################
  private

  @ignore_transactions = false

  # Returns the value of the local thread variable
  #
  # Parameters
  #   variable [Symbol]
  #     Name of variable to get
  if (RUBY_VERSION.to_i >= 2) && !defined?(Rubinius::VERSION)
    # Fibers have their own thread local variables so use thread_variable_get
    def self.thread_variable_get(variable)
      Thread.current.thread_variable_get(variable)
    end
  else
    def self.thread_variable_get(variable)
      Thread.current[variable]
    end
  end

  # Sets the value of the local thread variable
  #
  # Parameters
  #   variable [Symbol]
  #     Name of variable to set
  #   value [Object]
  #     Value to set the thread variable to
  if (RUBY_VERSION.to_i >= 2) && !defined?(Rubinius::VERSION)
    # Fibers have their own thread local variables so use thread_variable_set
    def self.thread_variable_set(variable, value)
      Thread.current.thread_variable_set(variable, value)
    end
  else
    def self.thread_variable_set(variable, value)
      Thread.current[variable] = value
    end
  end

end
