ENV["RAILS_ENV"] = "test"

require 'bundler/setup'
Bundler.require :default

begin
  require 'coveralls'
  Coveralls.wear!
rescue LoadError
  # Coveralls is only available for some rubies...
end

require 'minitest/autorun'
