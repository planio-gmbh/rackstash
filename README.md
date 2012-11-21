# Rackstash - Sane Logs for Rack and Rails

A gem which tames the Rack and Rails (2.3.x and 3.x) logs and generates JSON
log lines in the native [Logstash JSON Event format](http://logstash.net).

It is thus similar to the excellent
[Lograge](https://github.com/roidrage/lograge) by Mathias Meyer. The main
difference between Rackstash and Lograge is that Lograge attempts to
completely remove the existing logging and to replaces it with its own log
line. Rackstash instead retains the existing logs and just enhances them with
structured fields which can then be used in a Logstash environment. By
default, Rackstash collects the very same data that Lograge collects.

Given that Rackstash deals with potentially large amounts of log data per
request, it is not suitable for usage with syslog as it is restricted to 1024
Bytes. You should use something like
[beaver](https://github.com/josegonzalez/beaver) to ship the logs to a central
logstash server.

# Installation

Add this line to your application's Gemfile:

    gem 'rackstash'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rackstash

# Usage

## Rails 2

When using bundler (if not, you *really* should start using it), you can just
add Rackstash to your Gemfile as described above. Then, in the environment
you want to enable Rackstash output, add a simple

```ruby
require 'rackstash'
```

If you use `Bundler.require` during your Rails initialization, you can skip
the above step.

Note though that is is **not sufficient** to require Rackstash
in an initializer (i.e. one of the files in `config/initializers`) as these
files are evaluated too late during Rails initialization for Rackstash to
take over all of the Rails logging. You have to require it in either
`config/environment.rb` or one or more of
`config/environments/<environment name>.rb`.

Additionally, you can configure Rackstash by setting one or more of the
following configuration settings in the respective environment file.

```ruby
# The source attribute of all Logstash events
# By default: "unknown"
config.rackstash.source = "http://rails.example.com"

# Additional fields which are included into each log event that
# originates from a captured request.
# Can either be a hash or an object which responds to call and returns a
# hash.
config.rackstash.request_fields = proc do |request, params|
  {
    :host => request.host,
    :source_ip => request.headers['X-Forwarded-For']
  }
end

# Buffered logs events are emitted with this log level. If the logger is
# not buffering, it just passes the original log level through.
# Note that the underlying logger should log events with at least this log
# level
# By default: :info
config.rackstash.log_level = :info

# An array of strings with which all emited log events are tagged.
# By default empty.
config.rackstash.tags = ['ruby', 'rails2']
```

# Caveats

* Does only support Rails2 right now
* No tests yet :(

# Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
