source 'https://rubygems.org'

if ENV['RAILS_VERSION']
  gem "rails", "~> #{ENV['RAILS_VERSION']}"
elsif ENV['RACK_VERSION']
  gem "rack", "~> #{ENV['RACK_VERSION']}"
end
# mime-types >= 2.0.0 is only supported on Ruby >= 1.9.2
gem "mime-types", "< 2.0.0"

gem "rubysl", :platforms => [:rbx]

# Specify your gem's dependencies in rackstash.gemspec
gemspec
