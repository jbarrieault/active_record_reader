# Active Record Reader
[![Gem Version](https://img.shields.io/gem/v/active_record_reader.svg)](https://rubygems.org/gems/active_record_reader) [![Build Status](https://travis-ci.org/rocketjob/active_record_reader.svg?branch=master)](https://travis-ci.org/rocketjob/active_record_reader) [![Downloads](https://img.shields.io/gem/dt/active_record_reader.svg)](https://rubygems.org/gems/active_record_reader) [![License](https://img.shields.io/badge/license-Apache%202.0-brightgreen.svg)](http://opensource.org/licenses/Apache-2.0) ![](https://img.shields.io/badge/status-Production%20Ready-blue.svg) [![Gitter chat](https://img.shields.io/badge/IRC%20(gitter)-Support-brightgreen.svg)](https://gitter.im/rocketjob/support)

Redirect ActiveRecord (Rails) reads to reader databases while ensuring all writes go to the primary database.

* https://github.com/rocketjob/active_record_reader

## Introduction

active_record_reader redirects all database reads to reader instances while ensuring
that all writes go to the primary database. active_record_reader ensures that
any reads that are performed within a database transaction are by default directed to the primary
database to ensure data consistency.

## Status

Production Ready. Actively used in large production environments.

## Features

* Redirecting reads to a single reader database.
* Works with any database driver that works with ActiveRecord.
* Supports all Rails 3, 4, or 5 read apis.
    * Including dynamic finders, AREL, and ActiveRecord::Base.select.
* Transaction aware
    * Detects when a query is inside of a transaction and sends those reads to the primary by default.
    * Can be configured to send reads in a transaction to reader databases.
* Lightweight footprint.
* No overhead whatsoever when a reader is not configured.
* Negligible overhead when redirecting reads to the reader.
* Connection Pools to both databases are retained and maintained independently by ActiveRecord.
* The primary and reader databases do not have to be of the same type.
    * For example Oracle could be the primary with MySQL as the reader database.
* Debug logs include a prefix of `Reader: ` to indicate which SQL statements are going
  to the reader database.

### Example showing Reader redirected read

```ruby
# Read from the reader database
r = Role.where(name: 'manager').first
r.description = 'Manager'

# Save changes back to the primary database
r.save!
```

Log file output:

    03-13-12 05:56:05 pm,[2608],b[0],[0],  Reader: Role Load (3.0ms)  SELECT `roles`.* FROM `roles` WHERE `roles`.`name` = 'manager' LIMIT 1
    03-13-12 05:56:22 pm,[2608],b[0],[0],  AREL (12.0ms)  UPDATE `roles` SET `description` = 'Manager' WHERE `roles`.`id` = 5

### Example showing how reads within a transaction go to the primary

```ruby
Role.transaction do
  r = Role.where(name: 'manager').first
  r.description = 'Manager'
  r.save!
end
```

Log file output:

    03-13-12 06:02:09 pm,[2608],b[0],[0],  Role Load (2.0ms)  SELECT `roles`.* FROM `roles` WHERE `roles`.`name` = 'manager' LIMIT 1
    03-13-12 06:02:09 pm,[2608],b[0],[0],  AREL (2.0ms)  UPDATE `roles` SET `description` = 'Manager' WHERE `roles`.`id` = 4

### Forcing a read against the primary

Sometimes it is necessary to read from the primary:

```ruby
ActiveRecordReader.read_from_primary do
  r = Role.where(name: 'manager').first
end
```

## Usage Notes

### delete_all

Delete all executes against the primary database since it is only a delete:

```
D, [2012-11-06T19:47:29.125932 #89772] DEBUG -- :   SQL (1.0ms)  DELETE FROM "users"
```

### destroy_all

First performs a read against the reader database and then deletes the corresponding
data from the primary

```
D, [2012-11-06T19:43:26.890674 #89002] DEBUG -- :   Reader: User Load (0.1ms)  SELECT "users".* FROM "users"
D, [2012-11-06T19:43:26.890972 #89002] DEBUG -- :    (0.0ms)  begin transaction
D, [2012-11-06T19:43:26.891667 #89002] DEBUG -- :   SQL (0.4ms)  DELETE FROM "users" WHERE "users"."id" = ?  [["id", 3]]
D, [2012-11-06T19:43:26.892697 #89002] DEBUG -- :    (0.9ms)  commit transaction
```

## Transactions

By default ActiveRecordReader detects when a call is inside a transaction and will
send all reads to the _primary_ when a transaction is active.

It is now possible to send reads to database readers and ignore whether currently
inside a transaction:

In file config/application.rb:

```ruby
# Read from reader even when in an active transaction
config.active_record_reader.ignore_transactions = true
```

It is important to identify any code in the application that depends on being
able to read any changes already part of the transaction, but not yet committed
and wrap those reads with `ActiveRecordReader.read_from_primary`

```ruby
Inquiry.transaction do
  # Create a new inquiry
  Inquiry.create
  
  # The above inquiry is not visible yet if already in a Rails transaction.
  # Use `read_from_primary` to ensure it is included in the count below:
  ActiveRecordReader.read_from_primary do
    count = Inquiry.count
  end

end
```

## Note

ActiveRecord::Base.execute is sometimes used to perform custom SQL calls against
the database to bypass ActiveRecord. It is necessary to replace these calls
with the standard ActiveRecord::Base.select call for them to be picked up by
active_record_reader and redirected to the reader.

This is because ActiveRecord::Base.execute can also be used for database updates
which we do not want redirected to the reader

## Install

Add to `Gemfile`

```ruby
gem 'active_record_reader'
```

Run bundler to install:

```
bundle
```

Or, without Bundler:

```
gem install active_record_reader
```

## Configuration

To enable reader reads for any environment just add a _reader:_ entry to database.yml
along with all the usual ActiveRecord database configuration options.

For Example:

```yaml
production:
  database: production
  username: username
  password: password
  encoding: utf8
  adapter:  mysql
  host:     primary1
  pool:     50
  reader:
    database: production
    username: username
    password: password
    encoding: utf8
    adapter:  mysql
    host:     reader1
    pool:     50
```

Sometimes it is useful to turn on reader reads per host, for example to activate
reader reads only on the linux host 'batch':

```yaml
production:
  database: production
  username: username
  password: password
  encoding: utf8
  adapter:  mysql
  host:     primary1
  pool:     50
<% if `hostname`.strip == 'batch' %>
  reader:
    database: production
    username: username
    password: password
    encoding: utf8
    adapter:  mysql
    host:     reader1
    pool:     50
<% end %>
```

If there are multiple readers, it is possible to randomly select a reader on startup
to balance the load across the readers:

```yaml
production:
  database: production
  username: username
  password: password
  encoding: utf8
  adapter:  mysql
  host:     primary1
  pool:     50
  reader:
    database: production
    username: username
    password: password
    encoding: utf8
    adapter:  mysql
    host:     <%= %w(reader1 reader2 reader3).sample %>
    pool:     50
```

Readers can also be assigned to specific hosts by using the hostname:

```yaml
production:
  database: production
  username: username
  password: password
  encoding: utf8
  adapter:  mysql
  host:     primary1
  pool:     50
  reader:
    database: production
    username: username
    password: password
    encoding: utf8
    adapter:  mysql
    host:     <%= `hostname`.strip == 'app1' ? 'reader1' : 'reader2' %>
    pool:     50
```

## Dependencies

* Tested on Rails 3 and Rails 4

See [.travis.yml](https://github.com/reidmorrison/active_record_reader/blob/primary/.travis.yml) for the list of tested Ruby platforms

## Possible Future Enhancements

* Support for multiple named readers (ask for it by submitting an issue)

## Versioning

This project uses [Semantic Versioning](http://semver.org/).

## Author

[Reid Morrison](https://github.com/reidmorrison) :: @reidmorrison
