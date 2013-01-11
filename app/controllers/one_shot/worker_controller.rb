require 'will_paginate'

class OneShot::WorkerController < AdminController

  def index
    page = params[:page] || 1
    per_page = params[:pp] || 50
    @workers = Worker.paginate(:all, :order=>'id DESC', :page=>page, :per_page=>per_page) #.select { |worker| worker.info.total_votes > 0 }
  end
  
  def detail
    if @worker = Worker.find_by_id(params[:id])
      @bad_votes = Vote.find(:all, :conditions=>"worker_id = #{@worker[:id]} and correct = 'no'", :order=>'id DESC', :limit=>50)
    end
  end
  
end