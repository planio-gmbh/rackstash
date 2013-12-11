ENV["RAILS_ENV"] = "test"

require 'bundler/setup'
Bundler.require :default

unless RbConfig::CONFIG["RUBY_INSTALL_NAME"] == "rbx"
  require 'coveralls'
  Coveralls.wear!
end

require 'minitest/autorun'
