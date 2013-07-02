class VideosController < ApplicationController

  before_filter :require_yummy_cookie
  before_filter :identify_worker
  before_filter :require_user

  def index

    min_id = params[:min_id]
    per_page = (params[:pp] || 30).to_i

    @videos = Video.fetch_pending(min_id, per_page)

    # Process from the queue if we have no videos.
    Video.process_notification_queue if @videos.blank?
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
      render :json => { :message => "video not found" }
      return
    end

    action = params[:video][:action]
    if ! %w[pass fail hold].include?(action)
      render :json => { :message => "unknown action" }
      return
    end

    if ! request.post?
      render :json => { :message => "you must POST to perform this action" }
      return
    end

    video_params = params[:video].dup
    if action == 'hold'
      video.status = 'held'
      video.hold_comments = video_params[:hold_comments]
      video.save
    else
      # Make sure params contains the Video id.  This eventually goes into the
      # Video.notification_queue.
      video_params[:id] = video.id
      video.create_vote(action, video_params, @current_worker)
    end

    render :json => { :message => 'success' }
  end

  # Trigger delivery of callbacks in the queue.
  def deliver_callbacks
    if ! request.post?
      render :json => { :message => "You must POST to do this" }, :status => 400
      return
    end
    Video.process_notification_queue
    render :json => { :message => 'success' }
  end

end
