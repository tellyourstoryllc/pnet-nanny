module Peanut::ErrorLog

  def self.log_error(description, bucket=nil)
    unless @skip_logging
      bucket ||= self.class.name
      UseLog.increment(bucket)
      Rails.logger.error("ERROR: #{bucket}- #{description}")
    end
  end

  def log_error(description, bucket=nil)
    unless @skip_logging
      if self.respond_to?(:id)
        bucket ||= "#{self.class.name}:#{self.id}"
      else
        bucket ||= self.class.name
      end
      UseLog.increment(bucket)
      Rails.logger.error("ERROR: #{bucket}- #{description}")
    end
  end

end