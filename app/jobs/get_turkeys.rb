#!/usr/bin/env ruby
require 'rubygems'
require 'daemons'
require 'timeout'

ROOT = File.expand_path(File.dirname(__FILE__)+'/../../')
project = File.basename(ROOT)
procname = "#{project}_#{File.basename(__FILE__,'.rb')}"

# ---------------------------------------------------------------------------

Daemons.run_proc(procname, :dir_mode => :normal, :dir=>"#{ROOT}/log/",:log_output =>true, :backtrace=>true) do  
  require "#{ROOT}/config/environment.rb"

  loop do

    begin
      
      Photo.connection.reconnect!
      UseLog.connection.reconnect!  
      UseLog::UseLogCache.connection.reconnect!  
      vote_threshold = Peanut::Env['VOTE_THRESHOLD'] || 10
      min_score = Peanut::Env['MIN_SCORE'] || 70
      
      if funds = Turkey.adapter.availableFunds and funds < 100
        MyMailer.deliver_generic(:recipients=>'jimyoung@gmail.com', :subject=>"MTurk funds: $#{funds}", :body=>'Time to add more money!')
        sleep 1800
        next
      end
      
      # Fetch and process results
      
      all_displayed = []
      
      Turkey.reviewable_results.each do |result|
        worker = result[:WorkerId]
        assignment_id = result[:AssignmentId]

        displayed = nil
        flagged = nil

        Turkey.adapter.approveAssignment(:AssignmentId => assignment_id)
        UseLog.increment("turkey/approve_assignment")
        
        if xml_data = result[:Answer] and data = XmlSimple.xml_in(xml_data)
          if answer_data = data['Answer']
            answer_data.each do |answer|
              if answer['QuestionIdentifier'][0] == "displayed[]"
                displayed = answer['FreeText'][0].split('|').map { |fid| fid.to_i }
              elsif answer['QuestionIdentifier'][0] == "flagged[]"
                flagged = answer['FreeText'][0].split('|').map { |fid| fid.to_i }
              end
            end
          end
          
          if displayed and flagged
            all_displayed += displayed
            approved = displayed - flagged
            worker_id = Worker.cid_to_id("#{worker}_turkey")

            if result[:HITTypeId] == Turkey.text_hit_type_id
              approved.each do |tid|
                if txt = TextItem.find_by_id(tid)
                  txt.vote(worker_id, true)
                  UseLog.increment("turkey/text/yes_vote")
                end
              end

              flagged.each do |tid|
                if txt = TextItem.find_by_id(tid)
                  txt.vote(worker_id, false)
                  UseLog.increment("turkey/text/no_vote")
                end
              end

            else
              approved.each do |fid|
                if foto = Photo.find_by_id(fid)
                  foto.vote(worker_id, true)
                  UseLog.increment("turkey/yes_vote")
                end
              end

              flagged.each do |fid|
                if foto = Photo.find_by_id(fid)
                  foto.vote(worker_id, false)
                  UseLog.increment("turkey/no_vote")
                end
              end

            end
          
            # if worker sucks
            worker = Worker.find(worker_id)
            if (worker.info.score < min_score.to_i) and worker.info.total_votes >= vote_threshold.to_i
              Turkey.adapter.blockWorker(:WorkerId => worker, :Reason => 'You marked several photos incorrectly.')
              UseLog.increment("turkey/block_worker")
              puts "#{Time.now.utc}\tBlocked worker_id #{worker_id}\tScore:#{worker.info.score}\tVotes:#{worker.info.total_votes}"
            end
            
          end
          
        end
      end
      
      # Check that there are enough pending pics for a full additional page
      if hit_max_id = Peanut::Env['hit_max_id']
        options = { :min_id=>hit_max_id.to_i+1, :status=>'pending', :min_age=>Turkey::QUEUE_DELAY_SECONDS }
        if more_pics = Photo.find(:all, :conditions=>Photo.conditions_for_find(options), :order=>'id ASC', :limit=>Turkey::PHOTOS_PER_HIT) and more_pics.size == Turkey::PHOTOS_PER_HIT
          Turkey.create_hit(more_pics.first[:id])
          Peanut::Env['hit_max_id'] = more_pics.last[:id]
          UseLog.increment("turkey/create_hit")
        end
      end

      # Check that there are enough pending pics for a full additional page
      # if text_hit_max_id = Peanut::Env['text_hit_max_id']
      #   options = { :min_id=>text_hit_max_id.to_i+1, :status=>'pending', :min_age=>Turkey::QUEUE_DELAY_SECONDS }
      #   if more_txts = TextItem.find(:all, :conditions=>TextItem.conditions_for_find(options), :order=>'id ASC', :limit=>Turkey::TEXTS_PER_HIT) and more_pics.size == Turkey::TEXTS_PER_HIT
      #     Turkey.create_text_hit(more_txts.first[:id])
      #     Peanut::Env['text_hit_max_id'] = more_txts.last[:id]
      #     UseLog.increment("turkey/text/create_hit")
      #   end
      # end

      Turkey.dispose_reviewable_hits
      
      sleep(20)
    rescue SystemExit
      break
      
    rescue Exception => err
      puts "#{Time.now.utc}\t#{err.inspect}\t#{err.backtrace}"      
      sleep(15)
      puts "#{Time.now.utc}\tRETRY"
          
    ensure
      GC.start
    end
  end
end