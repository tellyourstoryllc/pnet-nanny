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
            { :id => 0,
              :title => "Video Too Dark",
            },
            { :id => 1,
              :title => "Sideways or Upside Down",
            },
            { :id => 2,
              :title => "No Sound or Bad Audio Quality",
            },
          ],
          :ratings => [
            { :type => 'radio',
              :name => 'attractiveness',
              :title => 'Attractiveness',
              :values => ['Below Average', 'Average', 'Above Average'],
            },
            { :type => 'radio',
              :name => 'scariness',
              :title => 'How Scary?',
              :values => ['Really Scary', 'A Little Scary', 'Fine'],
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

end
