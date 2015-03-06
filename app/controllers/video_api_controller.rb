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
    params[:video][:description] ||= params[:description] if params[:description].present?

    if params[:video][:url] !~ URI::regexp || params[:video][:callback_url] !~ URI::regexp
      render :json => { :error => "invalid url" }, :status => 400
      return
    end

    v = Video.new(params[:video])
    v.passthru = params[:video][:passthru] || params[:video][:passthrough]
    v.status = 'pending'
    v.save

    render json: {success: true, uuid: v.uuid}, status: 202
  end

  def delete
    require_params(:uuid) do
      video = Video.find_by_uuid(params[:uuid])

      if video
        video.destroy
        render :json=>{:success=>true}, :status=>200
      else
        render :json=>{:error=>"Video not found or already processed"}, :status=>400
      end
    end
  end

end
