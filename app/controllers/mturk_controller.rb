require 'uri'
class MturkController < ApplicationController
  
  layout 'mturk'    
  before_filter :print_session
  before_filter :identify_worker
  before_filter :require_yummy_cookie

  def review

    # If viewed through turk, assignmentId is passed in.
    @direct_view = params[:assignmentId].nil?

    if @task = Task.find(params[:task]) || Task.default

      @photos = []
      options = {}

      min_id = params[:min_id] || session["last_#{@task.name}_id"] || 0
      options[:min_id] = min_id.to_i + 1

      if pics = @task.fetch_assignments(@current_worker, min_id, params[:assignmentId]) and !pics.empty?
        @photos += pics
        session["last_#{@task.name}_photo_id"] = @photos.last.id
      end
    end
  end

  # This is the endpoint for submitted votes when review page is rendered directly. (not thru Mechanical Turk)
  def vote
    if @current_worker and taskname = params[:task]
      displayed = params[:displayed] || []
      displayed = displayed.map { |el| el.to_i }

      flagged = params[:flagged] || []
      flagged = flagged.map { |el| el.to_i }

      approved = displayed - flagged

      approved.each do |fid|
        if foto = Photo.find_by_id(fid)
          foto.create_vote('pass', taskname, @current_worker)
        end
      end

      flagged.each do |fid|
        if foto = Photo.find_by_id(fid)
          foto.create_vote('fail', taskname, @current_worker)
        end
      end
    end

    redirect_to :action=>'review'
  end
    
end