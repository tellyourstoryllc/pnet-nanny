class VideosController < ApplicationController

  before_filter :require_yummy_cookie
  before_filter :identify_worker
  before_filter :require_user

  def index

    min_id = params[:min_id] || 0
    per_page = params[:pp] || 25

    @videos = Video.fetch_assignments(@current_worker, min_id, per_page.to_i)
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

  # Manually trigger delivery of callbacks in the queue.
  def deliver_callbacks
    Photo.process_notification_queue
    render :text=>''
  end
  
end