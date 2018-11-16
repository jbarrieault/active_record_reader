module ActiveRecordReader #:nodoc:
  class Railtie < Rails::Railtie #:nodoc:

    # Make the ActiveRecordReader configuration available in the Rails application config
    #
    # Example: For this application ignore the current transactions since the application
    #          has been coded to use ActiveRecordReader.read_from_primary whenever
    #          the current transaction must be visible to reads.
    #            In file config/application.rb
    #
    #   Rails::Application.configure do
    #     # Read from reader even when in an active transaction
    #     # The application will use ActiveRecordReader.read_from_primary to make
    #     # changes in the current transaction visible to reads
    #     config.active_record_reader.ignore_transactions = true
    #   end
    config.active_record_reader = ::ActiveRecordReader

    # Initialize ActiveRecordReader
    initializer "load active_record_reader", :after => "active_record.initialize_database" do
      ActiveRecordReader.install!
    end

  end
end
