require 'uri'
require 'httparty'

class PhotoApiController < ApiController
  
  def submit
    # optional param: id
    require_params(:url, :callback_url) do

      # verify url and callback url
      if regexp = URI::regexp and params[:url] =~ regexp and params[:callback_url] =~ regexp

        # make sure we can "see" the photo
        if response = HTTParty.get(params[:url]) and response.code.to_i == 200

          p = Photo.new
          p.url = params[:url]
          p.min_votes = params[:min_votes]
          p.max_votes = params[:max_votes]
          p.client_id = @client.id
          p.passthru = params[:passthru] || params[:passthrough]
          p.callback_url = params[:callback_url]
          p.fingerprint
          p.save

          if params[:tasks] and tasks = [params[:tasks]].flatten
            tasks.each do |name|
              if t = Task.find(name)
                p.add_task(t)
              end
            end
          else
            p.add_task(Task.first)
          end

          render :json=>{:success=>true}, :status=>202
        else
          render :json=>{:error=>"unable to fetch image url", :url=>params[:url]}, :status=>404
        end
      else
        render :json=>{:error=>"invalid url"}, :status=>400
      end      
    end
  end
  
  def delete
    require_params(:url) do
      if p = Photo.find_by_url(params[:url]) and p.status == 'pending'
        p.delete
        render :json=>{:success=>true}, :status=>200
      else
        render :json=>{:error=>"photo not found or already processed"}, :status=>400
      end
    end
  end

  def pop
    require_params(:cid) do
      if photo = Photo.random(params[:cid])
        render :json=>{:url=>photo.url}, :status=>200
      else
        render :nothing=>true, :status=>204
      end
    end
  end
  
  def vote
    require_params(:cid, :url, :vote, :task) do 
      worker_id = Worker.cid_to_id(params[:cid])
      unless (photo = Photo.find_by_url(params[:url]))
        render :json=>{:error=>"photo not found, or photo already processed"}, :status=>400
        return
      end
      approved = (params[:vote].to_i == 1)
      increment_log "#{approved}"
      
      if photo.status == 'pending'
        photo.vote(worker_id, approved)
      else # a 'training' exercise
        # now we see if the vote was good
        good = true
        good = false if (approved and photo.status == 'rejected')
        good = false if (!approved and photo.status == 'approved')

        vote = Vote.new
        vote.worker_id = worker_id
        vote.photo_id = self.id      
        vote.vote = approved
        vote.good = good ? 'yes' : 'no'
        vote.save
        vote

        Photo.calculate_scores([worker_id])
      end

      worker = Worker.find_by_id(worker_id)
      info = worker.info
      render :json=>{:success=>true, :status=>photo.status, :pass_votes=>photo.pass_votes, :fail_votes=>photo.fail_votes, :user_votes=>info.total_votes, :user_score=>info.score}, :status=>202
    end
  end  
  
end