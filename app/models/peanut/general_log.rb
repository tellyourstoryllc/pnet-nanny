module Peanut::GeneralLog

  def self.log_event(description, bucket=nil, type=nil)
    unless @skip_logging
      bucket ||= self.class.name
      type ||= 'event'
      UseLog.increment("#{type}#{UseLog::SEPARATOR}#{bucket}")
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
      type ||= 'event'

      if type == 'error'
        Rails.logger.error("#{bucket} #{type}: #{description}")
      else
        Rails.logger.info("#{bucket} #{type}: #{description}")
      end

      UseLog.increment("#{type}#{UseLog::SEPARATOR}#{bucket}")
    end
  end

  def log_error(d,b)
    self.log_event(d,b, 'error')
  end

end