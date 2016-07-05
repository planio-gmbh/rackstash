source 'https://rubygems.org'

if ENV['RAILS_VERSION']
  gem "rails", "~> #{ENV['RAILS_VERSION']}"

  if RUBY_VERSION < '2'
    gem "rack-cache", '< 1.3'
    # gem "json", "< 2"
  end
elsif ENV['RACK_VERSION']
  gem "rack", "~> #{ENV['RACK_VERSION']}"
end

if RUBY_VERSION < "2"
  gem "mime-types", "< 2.0.0"
  gem "json", "< 2"

  gem "rake", "~> 10.5.0"

  if RUBY_VERSION < '1.9.3'
    gem "i18n", "~> 0.6.11"
    gem "activesupport", "< 4"
  else
    gem "i18n", "~> 0.7"
    gem "activesupport", "< 5"
  end
elsif RUBY_VERSION < "2.2.2"
  gem "activesupport", "< 5"
  gem "coveralls"
else
  gem "coveralls"
end

# Specify your gem's dependencies in rackstash.gemspec
gemspec
