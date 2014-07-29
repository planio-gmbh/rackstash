# Rackstash - Sane Logs for Rack and Rails

A gem which tames the Rack and Rails (2.3.x and 3.x) logs and generates JSON
log lines in the native [Logstash JSON Event format](http://logstash.net).

It is thus similar to the excellent
[Lograge](https://github.com/roidrage/lograge) by Mathias Meyer. The main
difference between Rackstash and Lograge is that Lograge attempts to
completely remove the existing logging and to replaces it with its own log
line. Rackstash instead retains the existing logs and just enhances them with
structured fields which can then be used in a Logstash environment. By
default, Rackstash collects the very same data that Lograge collects plus the
original full request log.

Given that Rackstash deals with potentially large amounts of log data per
request, it might be difficult to use with syslog. You would have to set the
supported message size rather high and have to make sure that all syslog
servers can handle the large messages. Rackstash is known to work with a
[syslog_logger](https://rubygems.org/gems/SyslogLogger) as the underlying
logger when its shipping to a sufficiently configured rsyslog.

In any case is probably much easier to setup Logstash directly on the
application server to read the logs from the default log file location and
to eventually forward them to their final destination.

# Installation

Add this line to your application's Gemfile:

    gem 'rackstash'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rackstash

# Usage

## Rails 3, Rails 4

Just add Rackstash to your Gemfile as described above. Then, in the
environment you want to enable Rackstash output, add a simple

```ruby
# config/environments/production.rb
MyApp::Application.configure do
  config.rackstash.enabled = true
end
```

Additionally, you can configure Rackstash by setting one or more of the
settings described in the configuration section below in the respective
environment file.

## Rails 2

When using bundler (if not, you *really* should start using it), you can just
add Rackstash to your Gemfile as described above. Then, in the environment
you want to enable Rackstash output, add a simple

```ruby
require 'rackstash'
config.rackstash.enabled = true
```

If you use `Bundler.require` during your Rails initialization, you can skip
the first line of the above step.

Note though that is is **not sufficient** to require Rackstash
in an initializer (i.e. one of the files in `config/initializers`) as these
files are evaluated too late during Rails initialization for Rackstash to
take over all of the Rails logging. You have to require it in either
`config/environment.rb` or one or more of
`config/environments/<environment name>.rb`.

Additionally, you can configure Rackstash by setting one or more of the
settings described in the configuration section in the respective environment
file.

## Configuration

You have to set the `enabled` attribute to `true` to convert the logs to JSON
using Rackstash:

```ruby
config.rackstash.enabled = true
```

Then you can configure a multitude of options and additional fields

```ruby
# The source attribute of all Logstash events
# By default: "unknown"
config.rackstash.source = "http://rails.example.com"

# An array of strings with which all emited log events are tagged.
# By default empty.
config.rackstash.tags = ['ruby', 'rails2']

# Additional fields which are included into each log event that
# originates from a captured request.
# Can either be a Hash or an object which responds to to_proc which
# subsequently returns a Hash. If it is the latter, the proc will be exceuted
# similar to an after filter in every request of the controller and thus has
# access to the controller state after the request was handled.
config.rackstash.request_fields = lambda do |controller|
  {
    :host => request.host,
    :source_ip => request.remote_ip,
    :user_agent => request.user_agent
  }
end

# Additional fields that are to be included into every emitted log, both
# buffered and not. You can use this to add global state information to the
# log, e.g. from the current thread or from the current environment.
# Similar to the request_fields, this can be either a static Hash or an
# object which responds to to_proc and returns a Hash there.
#
# Note that the proc is not executed in a controller instance and thus doesn't
# directly have access to the controller state.
config.rackstash.fields = lambda do
  {
    :thread_id => Thread.current.object_id,
    :app_server => Socket.gethostname
  }
end

# Buffered logs events are emitted with this log level. If the logger is
# not buffering, it just passes the original log level through.
# Note that the underlying logger should log events with at least this log
# level
# By default: :info
config.rackstash.log_level = :info
```

# Caveats

* Few tests
* No plain Rack support yet

# Contributing

[![Gem Version](https://badge.fury.io/rb/rackstash.png)](https://rubygems.org/gems/rackstash)
[![Build Status](https://secure.travis-ci.org/planio-gmbh/rackstash.png?branch=master)](https://travis-ci.org/planio-gmbh/rackstash)
[![Code Climate](https://codeclimate.com/github/planio-gmbh/rackstash.png)](https://codeclimate.com/github/planio-gmbh/rackstash)
[![Coverage Status](https://coveralls.io/repos/planio-gmbh/rackstash/badge.png?branch=master)](https://coveralls.io/r/planio-gmbh/rackstash?branch=master)

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

# License

MIT. Code extracted from [Planio](http://plan.io).
Copyright (c) 2012-2014 Holger Just, Planio GmbH
