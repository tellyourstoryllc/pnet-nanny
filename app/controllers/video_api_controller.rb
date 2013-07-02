# This is the controller that client applications should call in to to submit a
# video.
class VideoApiController < ApiController

  def submit
    if params[:video][:url] !~ URI::regexp || params[:video][:callback_url] !~ URI::regexp
      render :json => { :error => "invalid url" }, :status => 400
      return
    end

    v = Video.new(params[:video])
    v.passthru = params[:video][:passthru] || params[:video][:passthrough]
    v.status = 'pending'
    v.save

    render :json=>{:success=>true}, :status=>202
  end

end
