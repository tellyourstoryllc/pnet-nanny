source 'https://rubygems.org'

gem 'rails', '3.2.12'

# Bundle edge Rails instead:
# gem 'rails', :git => 'git://github.com/rails/rails.git'

gem 'mysql2'
gem 'aws-sdk' # AWS support
gem 'ruby-aws' # Needed because aws-sdk does not support mechanical turk: http://rubygems.org/gems/ruby-aws

# Use unicorn as the app server
gem 'unicorn'

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails',   '~> 3.2.3'
  gem 'coffee-rails', '~> 3.2.1'

  # See https://github.com/sstephenson/execjs#readme for more supported runtimes
  # gem 'therubyracer', :platforms => :ruby

  gem 'uglifier', '>= 1.0.3'

  gem 'therubyracer'
  gem 'less-rails'
  gem 'less-rails-bootstrap', '3.3.1.0'
end

gem 'jquery-rails'

gem 'redis'
gem 'redis-objects', :require => 'redis/objects'

gem 'mini_magick'

# Perceptual hash
#gem 'phashion'

# Pagination
gem 'will_paginate', '~> 3.0'

# Markdown converter
gem 'kramdown'

gem 'builder'

gem 'httparty'

# To use ActiveModel has_secure_password
gem 'bcrypt-ruby', '~> 3.0.0'

# To use Jbuilder templates for JSON
# gem 'jbuilder'

# Use unicorn as the app server
# gem 'unicorn'

# Deploy with Capistrano
# gem 'capistrano'

group :development, :test do
  # To use debugger
  gem 'debugger'
  gem 'pry-rails'
  gem 'pry-doc'
  gem 'awesome_print'
end
