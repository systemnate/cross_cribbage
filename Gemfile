# Gemfile
source "https://rubygems.org"

gem "rails", "~> 8.0.2"
gem "propshaft"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "solid_cable", "~> 3.0"
gem "vite_rails", "~> 3.0"
gem "rack-cors"
gem "bootsnap", require: false
gem "thruster", require: false
gem "tzinfo-data", platforms: %i[windows jruby]

group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "rspec-rails", "~> 7.0"
  gem "factory_bot_rails"
end

group :development do
  gem "web-console"
  gem "foreman"
end

group :test do
  gem "shoulda-matchers"
end
