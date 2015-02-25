class DummyController < ApplicationController

  before_filter :identify_worker, :require_staff

  def submit
    if params[:submit] and url = params[:url] and !url.blank?
      c = ApiClient.new
      @result = c.post '/api/photo/submit', { :url=>url, :callback_url=>url_for(:action=>:callback), :passthru=>{:submitted=>Time.now.utc} }
      @response = c.response
    end
  end

  def callback
    Rails.logger.info "Callback! #{params.inspect}"
    render :json=>{:success=>true}
  end

  # Manually trigger delivery of callbacks in the queue.
  def deliver_callbacks
    Photo.process_notification_queue
    redirect_to :review
  end

end
