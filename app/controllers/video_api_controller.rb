# This is the controller that client applications should call in to to submit a
# video.
class VideoApiController < ApiController

  def submit
    params[:video] ||= {}
    params[:video][:url] ||= params[:url] if params[:url].present?
    params[:video][:callback_url] ||= params[:callback_url] if params[:callback_url].present?
    params[:video][:passthru] ||= params[:passthru] if params[:passthru].present?
    params[:video][:passthrough] ||= params[:passthrough] if params[:passthrough].present?
    params[:video][:reject_reasons] ||= params[:reject_reasons] if params[:reject_reasons].present?

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
