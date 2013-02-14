# #!/usr/bin/env ruby
# require 'rubygems'
# require 'httparty'

# ROOT = File.expand_path(File.dirname(__FILE__)+'/../../')
# project = File.basename(ROOT)
# procname = "#{project}_#{File.basename(__FILE__,'.rb')}"


# # ---------------------------------------------------------------------------

# Daemons.run_proc(procname, :dir_mode => :normal, :dir=>"#{ROOT}/log/",:log_output =>true, :backtrace=>true) do  
#   require "#{ROOT}/config/environment.rb"

#   loop do

#     begin
#       Photo.connection.reconnect!
#       UseLog.connection.reconnect!  
#       UseLog::UseLogCache.connection.reconnect!  
      
#       count = 0
#       error_ids = []
      
#       while !Photo.notification_queue.empty?
#         # make sure we reconnect to the DB every so often.
#         count += 1
#         break if count == 500

#         photo_id = Photo.notification_queue.shift
        
#         # ensure photo exists
#         unless photo = Photo.find_by_id(photo_id)
#           puts "#{Time.now.utc}\t#{photo_id}\tnot found"
#           next
#         end

#         # ensure photo is not deleted / pending
#         if photo.status == 'deleted' or photo.status == 'pending'
#           puts "#{Time.now.utc}\t#{photo_id}\t#{photo.status}"
#           next
#         end
        
#         # update user scores
#         photo.mark_good_votes
        
#         # construct callback value, w/ secret sauce        
#         timestamp = Time.new.to_i
#         callback_value =  {:url=>photo.url, :ts=>timestamp, :status=>photo.status, :score=>photo.score}
#         callback_value[:id] = photo.app_id if photo.app_id
#         secret = "M3G4#{callback_value[:url]}#{callback_value[:status]}#{callback_value[:ts]}M0D"
#         callback_value[:ss] = Digest::MD5.hexdigest(secret).upcase

#         # make the callback
#         begin
#           if photo.callback_url
#             HTTParty.post(photo.callback_url, :body=>callback_value)
#           else
#             puts "#{Time.now.utc}\t#{photo_id}\tNO callback_url\t#{photo.url}"
#           end
#         rescue Exception => err
#           puts "#{Time.now.utc}\t#{photo_id}\tagent_fail\t#{photo.status}\t#{photo.callback_url}\t#{err.inspect}"
#           # fail silently, but put the photo back in the queue.
#           error_ids << photo.id
#           UseLog.increment("approval_queue/callback_error")
#         else
#           puts "#{Time.now.utc}\t#{photo_id}\tsuccess\t#{photo.status}\tY:#{photo.pass_votes}/N:#{photo.fail_votes}\t#{photo.url}"
#           UseLog.increment("approval_queue/callback_success")
#         end        
#         # sleep(1)
#       end

#       error_ids.each { |id| Photo.notification_queue << id }
#       sleep(5)      
      
#     rescue SystemExit
#       break
      
#     rescue Exception => err
#       puts "#{Time.now.utc}\t#{err.inspect}\t#{err.backtrace}"      
#       sleep(15)
#       puts "#{Time.now.utc}\tRETRY"
          
#     ensure
#       GC.start
#     end
#   end
# end