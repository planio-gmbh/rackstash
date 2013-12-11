ENV["RAILS_ENV"] = "test"

require 'bundler/setup'
Bundler.require :default

require 'coveralls'
Coveralls.wear!

require 'minitest/autorun'
