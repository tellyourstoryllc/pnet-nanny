class ApiController < ApplicationController 
  
  before_filter :check_client_token
  after_filter :log_activity

  def render_error(msg=nil, code=nil, &block)
    msg ||= 'error'
    code ||= 404
    if is_error = block_given? ? yield : true
      render :json=>{ :error => { :message=>msg, :code=>code } }
      true
    end
  end

  alias_method :render_error_if, :render_error
   
  def render_success(msg=nil, &block)
    msg ||= 'success'
    if success = block_given? ? yield : true
      render :json=> { :result => { :message=>msg } }
      true
    end
  end

  alias_method :render_success_if, :render_success
  
  #============================================================================
  # FILTERS  
  
  # Log stuff here...
  def log_activity(action_label = nil, user = nil)
    unless @skip_logging
      action_label ||= "#{self.class.name}#{UseLog::SEPARATOR}#{params[:action]}"
      UseLog.increment(action_label)
    end
  end
  
  def check_client_token

    if client_token = params[:api_key] || params[:key]
      @client = Client.client_for(client_token)
    end

    if @client
      Rails.logger.info "@client:#{@client.id} (#{@client.name})" 
    else
      render_error('Invalid client') and return 
    end
  end

end
