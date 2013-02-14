# Options documented here:
# http://docs.aws.amazon.com/AWSRubySDK/latest/AWS.html#config-class_method

# load the libraries
require 'aws-sdk'
# log requests using the default rails logger
AWS.config(:logger => Rails.logger)
# load credentials from a file
config_path = File.expand_path(File.dirname(__FILE__)+"/../aws.yml")
AWS.config(YAML.load(File.read(config_path)))