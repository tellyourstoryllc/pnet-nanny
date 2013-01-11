class ApplicationController < ActionController::Base

  protected
  
  def print_session
    Rails.logger.info "Session: #{session}"
  end

  def identify_worker
    if uid = session[:worker_id] and token = session[:token]
      if worker = Worker.find_by_id(uid) and worker.token == token
        @current_worker = worker
      else
        log_activity("Cookie-based worker authentication failed- id:#{uid} token:#{token}")
      end
    end

    if @current_worker.nil?
      new_worker = Worker.new
      new_worker.creating_ip = request.env['HTTP_X_FORWARDED_FOR'] || request.env['REMOTE_ADDR']
      new_worker.save
      @current_worker = new_worker
      session[:worker_id] = new_worker.id
      session[:token] = new_worker.token
    end
  end
  
  # Log stuff here...
  def log_activity(action_label = nil)
    unless @skip_logging
      action_label ||= "#{self.class.name}#{UseLog::SEPARATOR}#{params[:action]}"
      UseLog.increment(action_label)
    end
  end

  helper_method :log_activity

  #============================================================================
  # RANDOM UTILITY METHODS
  
  def abort_if_missing_param?(*list, &block)
    missing = []
    list.each do |p| 
      missing << p unless params[p] 
    end
    
    if missing.empty?
      yield if block
    else 
      log_activity("missing_param")
      render :json=>{:error => "missing parameter(s): #{missing.join(', ')}"}, :status=>412
    end
  end

end