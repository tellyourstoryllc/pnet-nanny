class AdminController < ApplicationController

  before_filter :identify_worker
  
  def login
    if login = params[:login] and pw = params[:password]
      if worker = Worker.find_by_login(login) and worker.authenticate(pw)
        session[:worker_id] = worker.id
        session[:token] = worker.token
        redirect_to pending_videos_queue_url
      else
        flash[:error] = 'Login failed!'
      end
    end
  end

  def logout
    session[:worker_id] = nil
    session[:token] = nil
    redirect_to :action=>'login'
  end
  
end
