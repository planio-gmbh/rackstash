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
# Can either be a Hash or an object which responds to to_proc which
# subsequently returns a Hash. If it is the latter, the proc will be exceuted
# similar to an after filter in every request of the controller and thus has
# access to the controller state after the request was handled.
config.rackstash.request_fields = proc do
  {
    :host => request.host,
    :source_ip => request.headers['X-Forwarded-For'],
    :content-length => response.headers['Content-Length']
  }
end

# Additional fields that are to be included into every emitted log, both
# buffered and not. You can use this to add global state information to the
# log, e.g. from the current thread or from the current environment.
# Similar to the request_fields, this can be either a static Hash or an
# object which responds to to_proc and returns a Hash there.

config.rackstash.fields = proc do
  {
    :thread_id => Thread.current.object_id
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

[![Build Status](https://secure.travis-ci.org/planio-gmbh/rackstash.png?branch=master)](https://travis-ci.org/planio-gmbh/rackstash)

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

# License

MIT. Code extracted from [Planio](http://plan.io).
Copyright (c) 2012 Holger Just, Planio GmbH