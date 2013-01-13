class DummyController < ApplicationController

  def submit
    if params[:submit] and url = params[:url] and !url.blank?
      c = ApiClient.new
      @result = c.post '/api/photo/submit', { :url=>url, :callback_url=>url_for(:action=>:callback) }
      @response = c.response
    end
  end

  def callback
    Rails.logger.info "Callback! #{params.inspect}"
    render_success
  end

end