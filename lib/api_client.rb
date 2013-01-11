require 'httparty'

class ApiClient
  include HTTParty

  begin
    host_config = YAML.load_file("#{Rails.root}/config/host.yml")
    env_host_config = host_config[Rails.env]
    host = env_host_config['url']
    base_uri host
    HOST = host
  rescue Exception => err
    puts "Unable to load `config/host.yml. See config/host.yml.sample for an example."
    throw Exception.new("Error loading `config/host.yml.")
  end

  attr_accessor :client_token, :name

  def initialize(options={})
    @client_token = options[:client_token]
    @name = options[:name]
  end

  def self.normalize_parameters(value)
    case value
    when Hash
      h = {}
      value.each { |k, v| h[k] = normalize_parameters(v) }
      h.with_indifferent_access
    when Array
      value.map { |e| normalize_parameters(e) }
    else
      value
    end
  end

  def post(endpoint, options={})
    begin
      result = self.class.post(
        endpoint,
        :body => options.merge({:api_key=>@client_token}).to_json, 
        :headers => { 'Content-Type' => 'application/json' },
        :timeout => 999999
        )
      ApiClient.normalize_parameters(result.parsed_response)
    rescue Errno::ECONNREFUSED
      puts "Unable to connect to server on #{HOST}."
    end
  end
end
