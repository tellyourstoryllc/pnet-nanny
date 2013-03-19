require 'will_paginate'

class ReviewController < ApplicationController

  before_filter :require_yummy_cookie
  before_filter :identify_worker
  before_filter :require_user
  before_filter :identify_task

  def index

    page = params[:page] || 1
    per_page = params[:pp] || 25
    
    if @task
      min_id = params[:min_id] || 0
      @photos = @task.fetch_assignments(@current_worker, min_id)[0..per_page.to_i]
      Photo.process_notification_queue if @photos.nil? or @photos.empty?
    end
  end

  def next_page
    render :text=>''
  end
        
  # AJAX endpoints
  
  def approve
    if foto = Photo.find(params[:id]) and @task
      foto.create_vote(:pass, @task.name, @current_worker)
    end
    render :text=>''
  end

  def reject
    if foto = Photo.find(params[:id]) and @task
      foto.create_vote(:fail, @task.name, @current_worker)
    end
    render :text=>''
  end

  def borken
    render :text=>''
  end
  
    # Manually trigger delivery of callbacks in the queue.
  def deliver_callbacks
    Photo.process_notification_queue
    render :text=>''
  end

  protected 
  
  def identify_task
    @task = Task.find(params[:task]) || Task.default
  end
  
end