class AdminController < ApplicationController

  before_filter :identify_worker
  
  def login
    if params[:login] and name = params[:username] and pw = params[:password]
      if account = Worker.find_by_username(name) and account.authenticate(pw)
        session[:worker_id] = account.id
        session[:token] = account.token
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
