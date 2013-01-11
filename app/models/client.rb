# Client is an app that uses the API. (Not individual end users)

class Client < Peanut::ActivePeanut::Base

  attr_accessible :name, :signature, :status, :level

  def self.client_for(token)
    sig, client_id = token.split('-')
    return nil if not(sig && client_id)
    client_id = client_id.to_i(36)
    begin
      client = self.find(:first, :conditions=>['id=:client_id and signature=:sig', {:client_id=>client_id, :sig=>sig}])
      return client && client.status == 'active' ? client : nil
    rescue ActiveRecord::RecordNotFound
      nil
    end
  end

  def save
    self.signature ||= Peanut::Toolkit.rand_string(Time.now.utc)[0..15]
    self.status ||= 'active'
    super
  end

  def token
    "#{self.signature}-#{self.id.to_s(36)}"
  end

  def api_client(options={})
    require 'api_client'
    @client ||= begin
      ac = ApiClient.new
      ac.client_token = self.token
      ac
    end
  end

end
