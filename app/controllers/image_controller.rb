require 'will_paginate'

class ImageController < AdminController

  def index
    page = params[:page] || 1
    per_page = params[:pp] || 50
    conditions = ""
    if params[:status] && %w(pending approved rejected unclear deleted).include?(params[:status])
      conditions = ["status = ?", params[:status]]
    end

    @rows = Photo.paginate(:all, :conditions=>conditions, :order=>"created_at DESC", :page=>page, :per_page=>per_page)
  end

end