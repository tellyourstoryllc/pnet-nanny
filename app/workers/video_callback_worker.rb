require 'securerandom'

class VideoCallbackWorker

  # Mini implementation of Sidekiq API.
  def self.perform_async(*args)
    QueueProcessor.push(self, args)
  end

  def perform(vote_id)
    vote = Vote.find(vote_id)
    video = vote.try(:video)
    return false unless video

    # Attempt to deliver the callback to the client application.  This will
    # rasie if it fails.
    video.deliver_callback(vote)
    # Remove references to the video and delete it.
    vote.video_id = nil
    vote.save
    video.destroy

    true
  end

end
