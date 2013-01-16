module Peanut::ErrorLog

  def self.log_event(description, bucket=nil, type=nil)
    unless @skip_logging
      bucket ||= self.class.name
      UseLog.increment("#{bucket}-#{type}")
      type ||= 'unknown'
      if type == 'error'
        Rails.logger.error("#{bucket} #{type}: #{description}")
      else
        Rails.logger.info("#{bucket} #{type}: #{description}")
      end
    end
  end

  def self.log_error(d,b)
    self.log_event(d,b, 'error')
  end

  def log_event(description, bucket=nil, type=nil)
    unless @skip_logging
      if self.respond_to?(:id)
        bucket ||= "#{self.class.name}:#{self.id}"
      else
        bucket ||= self.class.name
      end
      type ||= 'unknown'

      UseLog.increment("#{bucket}-#{type}")
      if type == 'error'
        Rails.logger.error("#{bucket} #{type}: #{description}")
      else
        Rails.logger.info("#{bucket} #{type}: #{description}")
      end
    end
  end

  def log_error(d,b)
    self.log_event(d,b, 'error')
  end

end