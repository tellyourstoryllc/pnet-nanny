class AdminController < ApplicationController

  def login
    if name = params[:username] and pw = params[:pw]
      if account = Worker.find_by_username(name) and account.password == pw
        session[:worker_id] = account.id
        session[:token] = account.token
      end
    end
  end

  def logout
    session[:worker_id] = nil
    session[:token] = nil
    redirect_to :action=>'login'
  end

end