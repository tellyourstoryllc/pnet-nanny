require 'will_paginate'

class ReviewController < ApplicationController

  before_filter :require_yummy_cookie
  before_filter :identify_worker
  before_filter :require_worker

  def index
    page = params[:page] || 1
    per_page = params[:pp] || 25
    
    if @task = Task.find(params[:task]) || Task.default
      min_id = params[:min_id] || 0
      @photos = @task.fetch_assignments(@current_worker, min_id) 
    end
  end

  def next_page
    render :text=>''
  end
        
  # AJAX endpoints
  
  def approve
    if foto = Photo.find(params[:id])
      foto.pass_votes = 1
      foto.fail_votes = 0
      foto.save
      foto.mark_approved

      remove_div_for foto
    end
  end

  def reject
    if foto = Photo.find(params[:id])
      foto.fail_votes = 1
      foto.pass_votes = 0
      foto.save
      foto.mark_rejected

      increment_log('borken') if params[:borken]
      remove_div_for foto
    end
  end

  def update_photo
    if photo = Photo.find(params[:id])
      case params[:field]
      when 'status'
        if params[:value] == 'approved'
          photo.mark_approved
        elsif params[:value] == 'rejected'
          photo.mark_rejected
        elsif params[:value] == 'unclear'
          photo.mark_unclear
        elsif params[:value] == 'pending' || params[:value] == 'deleted'
          photo.status = params[:value]
          photo.save
        end
      end
      
      photo.save
      
      render :update do |p|
        p['alert'].replace_html(alert_div("#{params[:field]} of photo ##{photo.id} updated"))
      end      
    else 
      render :text=>''
    end
  end
  
  protected 
  
  def remove_div_for(foto)
    render(:update) do |page|
      page << <<-JS
      try { $('foto_#{foto[:id]}').remove(); }
      catch(err) {}
      JS
    end    
  end
  
end