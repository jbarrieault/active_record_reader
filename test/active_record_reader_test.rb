require File.join(File.dirname(__FILE__), 'test_helper')
require 'logger'
require 'erb'

l                                 = Logger.new('test.log')
l.level                           = ::Logger::DEBUG
ActiveRecord::Base.logger         = l
ActiveRecord::Base.configurations = YAML::load(ERB.new(IO.read('test/database.yml')).result)

# Define Schema in second database (reader)
# Note: This is not be required when the primary database is being replicated to the reader db
ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations['test']['reader'])

# Create table users in database active_record_reader_test
ActiveRecord::Schema.define :version => 0 do
  create_table :users, :force => true do |t|
    t.string :name
    t.string :address
  end
end

# Define Schema in primary database
ActiveRecord::Base.establish_connection(:test)

# Create table users in database active_record_reader_test
ActiveRecord::Schema.define :version => 0 do
  create_table :users, :force => true do |t|
    t.string :name
    t.string :address
  end
end

# AR Model
class User < ActiveRecord::Base
end

# Install ActiveRecord reader. Done automatically by railtie in a Rails environment
# Also tell it to use the test environment since Rails.env is not available
ActiveRecordReader.install!(nil, 'test')

#
# Unit Test for active_record_reader
#
class ActiveRecordReaderTest < Minitest::Test
  describe 'the active_record_reader gem' do

    before do
      ActiveRecordReader.ignore_transactions = false

      User.delete_all

      @name    = "Joe Bloggs"
      @address = "Somewhere"
      @user    = User.new(
        :name    => @name,
        :address => @address
      )
    end

    after do
      User.delete_all
    end

    it 'saves to primary' do
      assert_equal true, @user.save!
    end

    #
    # NOTE:
    #
    #   There is no automated replication between the SQL lite databases
    #   so the tests will be verifying that reads going to the "reader" (second)
    #   database do not find data written to the primary.
    #
    it 'saves to primary, read from reader' do
      # Read from reader
      assert_equal 0, User.where(:name => @name, :address => @address).count

      # Write to primary
      assert_equal true, @user.save!

      # Read from reader
      assert_equal 0, User.where(:name => @name, :address => @address).count
    end

    it 'save to primary, read from primary when in a transaction' do
      assert_equal false, ActiveRecordReader.ignore_transactions?

      User.transaction do
        # The delete_all in setup should have cleared the table
        assert_equal 0, User.count

        # Read from Primary
        assert_equal 0, User.where(:name => @name, :address => @address).count

        # Write to primary
        assert_equal true, @user.save!

        # Read from Primary
        assert_equal 1, User.where(:name => @name, :address => @address).count
      end

      # Read from Non-replicated reader
      assert_equal 0, User.where(:name => @name, :address => @address).count
    end

    it 'save to primary, read from reader when ignoring transactions' do
      ActiveRecordReader.ignore_transactions = true
      assert_equal true, ActiveRecordReader.ignore_transactions?

      User.transaction do
        # The delete_all in setup should have cleared the table
        assert_equal 0, User.count

        # Read from Primary
        assert_equal 0, User.where(:name => @name, :address => @address).count

        # Write to primary
        assert_equal true, @user.save!

        # Read from Non-replicated reader
        assert_equal 0, User.where(:name => @name, :address => @address).count
      end

      # Read from Non-replicated reader
      assert_equal 0, User.where(:name => @name, :address => @address).count
    end

    it 'saves to primary, force a read from primary even when _not_ in a transaction' do
      # Read from reader
      assert_equal 0, User.where(:name => @name, :address => @address).count

      # Write to primary
      assert_equal true, @user.save!

      # Read from reader
      assert_equal 0, User.where(:name => @name, :address => @address).count

      # Read from Primary
      ActiveRecordReader.read_from_primary do
        assert_equal 1, User.where(:name => @name, :address => @address).count
      end
    end

  end
end
