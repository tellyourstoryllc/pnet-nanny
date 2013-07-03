class VideoTestingController < ApplicationController

  before_filter :identify_worker

  def add
    if request.post?
      api = ApiClient.new
      @result = api.post '/api/video/submit', {
        :video => {
          :url => params[:url], :thumbnail_url => params[:thumbnail_url],
          :creator_url => url_for(:action => :add),
          :description => "Submitted through test interface",
          :reject_reasons => [
            { :id => 1,
              :title => "Video Too Dark",
            },
            { :id => 2,
              :title => "Sideways or Upside Down",
            },
            { :id => 3,
              :title => "No Sound or Bad Audio Quality",
            },
            { :id => 4,
              :title => "Inappropriate Content",
            },
          ],
          :ratings => [
            { :type => 'radio',
              :id => 1,
              :title => 'Attractiveness (5 is most)',
              :values => ['1', '2', '3', '4', '5'],
            },
            { :type => 'radio',
              :id => 2,
              :title => 'How Scary?',
              :values => ['Really Scary', 'A Little Scary', 'Fine'],
            },
            { :type => 'radio',
              :id => 2,
              :title => 'Education Level',
              :values => ['Low', 'Average', 'High'],
            },
          ],
          :callback_url => url_for(:action=>:callback),
          :passthru=>{:submitted=>Time.current.to_i},
        }
      }
      @response = api.response
    end
  end

  def callback
    Rails.logger.info "Callback! #{params.inspect}"
    render :json=>{:success=>true}
  end

  # Manually trigger delivery of callbacks in the queue.
  def deliver_callbacks
    if request.post?
      Video.process_notification_queue
    end
    render :nothing => true
  end

end
