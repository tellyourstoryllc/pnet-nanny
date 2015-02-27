require 'will_paginate'

class WorkerController < AdminController

  before_filter :identify_worker

  def index
    page = params[:page] || 1
    per_page = params[:pp] || 50
    @workers = Worker.paginate(:all, :order=>'id DESC', :page=>page, :per_page=>per_page) #.select { |worker| worker.info.total_votes > 0 }
  end
  
  def detail
    if @worker = Worker.find_by_id(params[:id])
      @bad_votes = Vote.find(:all, :conditions=>"worker_id = #{@worker[:id]} and correct = 'no'", :order=>'id DESC', :limit=>50)
    end
  end
  
  def register
    if params[:register] and @current_worker and !@current_worker.registered?

      @current_worker.username = params[:username]
      @current_worker.password = params[:password]
      @current_worker.email = params[:email]

      flash[:error] = "Please enter a username" and return if params[:username].blank?
      flash[:error] = "#{params[:username]} is not available" and return if Worker.find_by_username(params[:username])
      flash[:error] = "Password is blank or not confirmed." and return if params[:password].blank? or params[:confirm_password].blank? or (params[:password] != params[:confirm_password])
      flash[:error] = "Please enter a valid email address." and return if params[:email].blank?
      flash[:error] = "Please enter the correct registration code." and return if params[:code] != 'phosaigon'

      @current_worker.clearance = 1
      @current_worker.save

      session[:worker_id] = @current_worker.id
      session[:token] = @current_worker.token

      redirect_to home_url
    end
  end

  def edit
  end

  def update
    if params[:password]
      if !@current_worker.authenticate(params[:current_password])
        flash.now[:error] = 'Current password is incorrect.'
      elsif params[:password] != params[:confirm_password]
        flash.now[:error] = 'Confirmation password does not match.'
      else
        flash.now[:success] = 'Successfully changed your password.'
        @current_worker.update_attributes(update_params)
      end
    end

    render :edit
  end


  private

  def update_params
    params.slice(:password)
  end
end
