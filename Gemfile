source 'https://rubygems.org'

if ENV['RAILS_VERSION']
  gem "rails", "~> #{ENV['RAILS_VERSION']}"
elsif ENV['RACK_VERSION']
  gem "rack", "~> #{ENV['RACK_VERSION']}"
end
if RUBY_VERSION < '1.9.2'
  # mime-types >= 2.0.0 is only supported on Ruby >= 1.9.2
  gem "mime-types", "< 2.0.0"
  gem "activesupport", "< 4.0"
else
  # Coveralls is only available on Ruby > 1.9
  gem "coveralls"
end

# Specify your gem's dependencies in rackstash.gemspec
gemspec
