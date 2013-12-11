source 'https://rubygems.org'

if ENV['RAILS_VERSION']
  gem "rails", "~> #{ENV['RAILS_VERSION']}"
  gem "mime-types", "< 2.0.0", :platforms => [:ruby_18, :mingw_18]
elsif ENV['RACK_VERSION']
  gem "rack", "~> #{ENV['RACK_VERSION']}"
end

# Specify your gem's dependencies in rackstash.gemspec
gemspec
