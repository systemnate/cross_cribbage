# Gemfile
source "https://rubygems.org"

gem "rails", "~> 8.1.3"
gem "propshaft"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "solid_cable", "~> 3.0"
gem "solid_queue"
gem "solid_cache"
gem "vite_rails", "~> 3.0"
gem "rack-cors"
gem "rack-attack"
gem "bootsnap", require: false
gem "thruster", require: false
gem "tzinfo-data", platforms: %i[windows jruby]
gem "ostruct"

group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "rspec-rails", "~> 7.0"
  gem "factory_bot_rails"
  gem "brakeman", require: false
  gem "bundler-audit", require: false
  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "web-console"
  gem "foreman"
end

group :test do
  gem "shoulda-matchers"
  gem "simplecov", require: false
end

gem "dockerfile-rails", ">= 1.7", group: :development

gem "redis", "~> 5.4"

# ActiveSupport (8.0 and 8.1.3) passes quirks_mode, which json 3.x rejects
gem "json", "~> 2.21"
