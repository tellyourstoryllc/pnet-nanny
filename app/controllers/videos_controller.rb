class VideosController < ApplicationController

  before_filter :require_yummy_cookie
  before_filter :identify_worker
  before_filter :require_user

  def index

    min_id = params[:min_id]
    per_page = (params[:pp] || 25).to_i

    @videos = Video.fetch_pending(min_id, per_page)
  end

  def held
    min_id = params[:min_id]
    per_page = (params[:pp] || 25).to_i

    @videos = Video.fetch_held(min_id, per_page)
  end

  # AJAX endpoints
  
  def update
    video = Video.find(params[:id])
    if ! video
      render :text => "video not found"
      return
    end

    action = params[:video][:action]
    if ! %w[pass fail hold].include?(action)
      render :text => "unknown action"
      return
    end

    if ! request.post?
      render :text => "you must POST to perform this action"
      return
    end

    puts "*********************"
    require 'pp'; pp params

    if action == 'hold'
      video.status = 'held'
      video.save
    else
      # Make sure params contains the Video id.  This eventually goes into the
      # Video.notification_queue.
      video_params = params[:video].dup
      video_params[:id] = video.id
      video.create_vote(action, video_params, @current_worker)
    end

    render :text=>''
  end

  # Manually trigger delivery of callbacks in the queue.
  def deliver_callbacks
    Video.process_notification_queue
    render :text=>''
  end

end