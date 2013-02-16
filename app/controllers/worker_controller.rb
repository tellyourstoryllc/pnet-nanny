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

      flash.now[:notice] = "Please enter a username" and return if params[:username].blank?
      flash.now[:notice] = "#{params[:username]} is not available" and return if Worker.find_by_username(params[:username])
      flash.now[:notice] = "Password is blank or not confirmed." and return if params[:password].blank? or params[:confirm_password].blank? or (params[:password] != params[:confirm_password])
      flash.now[:notice] = "Please enter the correct registration code." and return if params[:code] != 'phosaigon'

      @current_worker.username = params[:username];
      @current_worker.password = params[:password];
      @current_worker.clearance = 1
      @current_worker.save
      flash[:notice] = "You are now registered."
      redirect_to(:review)
    end
  end
  
end