class ApplicationController < ActionController::Base

  include ::Peanut::GeneralLog
  
  def check_cookies
    if cookies[:yummy]
      redirect_to params[:target] || { :controller=>'mturk', :action=>'review' }
    else
      redirect_to('http://duckduckgo.com') 
    end
  end

  protected
  
  def print_session
    Rails.logger.info "Session: #{session}"
  end

  def require_yummy_cookie
    unless cookies[:yummy]
      cookies[:yummy] = 'chocolate'
      redirect_to :controller=>'application', :action=>'check_cookies', :target=>env['REQUEST_URI']
    end
  end

  def identify_worker
    if uid = session[:worker_id] and token = session[:token]
      if worker = Worker.find_by_id(uid) and worker.token == token
        @current_worker = worker
      end
    end

    if @current_worker.nil? and cookies[:yummy]
      new_worker = Worker.new
      new_worker.creating_ip = request.env['HTTP_X_FORWARDED_FOR'] || request.env['REMOTE_ADDR']
      new_worker.save
      @current_worker = new_worker
      session[:worker_id] = new_worker.id
      session[:token] = new_worker.token
    end
  end
  
  def require_worker
    redirect_to 'http://perceptualnet.com' unless @current_worker
  end

  # Log stuff here...
  def log_activity(action_label = nil)
    unless @skip_logging
      action_label ||= "#{self.class.name}#{UseLog::SEPARATOR}#{params[:action]}"
      UseLog.increment(action_label)
      UseLog.increment("client_#{@client.id}#{UseLog::SEPARATOR}#{action_label}") if @client
    end
  end

  helper_method :log_activity

  #============================================================================
  # RANDOM UTILITY METHODS
  
  def require_params(*list, &block)
    missing = []
    list.each { |p| missing << p if params[p].blank? }
    
    if missing.empty?
      yield if block
    else 
      render :json=>{:error => "missing parameter(s): #{missing.join(', ')}"}, :status=>412
    end
  end

end