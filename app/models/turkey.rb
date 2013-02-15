# Adapter for Mechanical Turk

require 'ruby-aws' # Needed because aws-sdk does not support mechanical turk: http://rubygems.org/gems/ruby-aws

# FYI. From https://forums.aws.amazon.com/thread.jspa?threadID=16066:
# "The SDK for Ruby allows you to call any WSDL operation directly against the MechanicalTurkRequester object even though the 
# method has not been explicitly defined. For web service methods that utilize paging, the developer can append an "All" to 
# the method name to automatically get all the results without calling paging operations.""

class Turkey

  LOG_FILE = "#{Rails.root}/log/aws.log"
  
  @@mturk = nil
  
  class << self

    def adapter
      @@mturk ||= begin
        if Settings.get('turk_environment') == 'sandbox'
          requester = Amazon::WebServices::MechanicalTurkRequester.new(:UseSSL=>true, :Transport=>:REST, :SoftwareName=>'PNet', :Host=>'sandbox')
        else
          requester = Amazon::WebServices::MechanicalTurkRequester.new(:UseSSL=>true, :Transport=>:REST, :SoftwareName=>'PNet', :Host=>'production')
        end
        requester.set_log LOG_FILE
        requester
      end
    end

    def reviewable_results
      hits = [].extend(MonitorMixin)
      self.adapter.getReviewableHITsAll.each { |hit| hits << hit }
      self.hit_assignments_for(hits, 'Submitted')
    end

    def dispose_reviewable_hits
      self.adapter.getReviewableHITsAll.each do |hit| 
        self.adapter.disposeHIT(:HITId=>hit[:HITId])
      end
    end

    protected

    def hit_assignments_for( list, status='Submitted' )
      results = [].extend(MonitorMixin)
      tp = Amazon::Util::ThreadPool.new(4)
      list.each do |line|
        tp.addWork(line) do |h|
          self.adapter.getAssignmentsForHITAll( :HITId=>h[:HITId], :AssignmentStatus=>status ).each do |assignment|
            results.synchronize do
              results << assignment
            end
          end
        end
      end
      tp.finish
      results.flatten
    end

  end
end