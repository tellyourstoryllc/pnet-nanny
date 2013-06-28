# Mini synchronous implementation of processing Sidekiq jobs.
class QueueProcessor
  include Peanut::Redis::Connection
  include Peanut::Redis::Objects

  # Queue of jobs.  Failed jobs are kept in `retry_queue` sorted set.  Jobs are
  # stored in the same format as Sidekiq.
  list :queue, :global => true
  sorted_set :retry_queue, :global => true

  class << self

    # Push a worker class and job args onto the queue.
    #
    # See: https://github.com/mperham/sidekiq/blob/master/lib/sidekiq/client.rb
    def push(klass, args)
      msg = {
        'class' => klass.to_s,
        'args' => args,
        'jid' => SecureRandom.hex(12),
        'enqueued_at' => Time.now.utc.to_f,
      }
      self.queue.unshift(JSON.generate(msg))

      msg['jid']
    end

    def work_off_queue
      num_succeeded = 0

      # Work all jobs in the queue.
      while payload = self.queue.pop
        succeeded = process_payload(payload)
        num_succeeded += 1 if succeeded
      end

      # Retry failed jobs.
      redis.zrangebyscore(self.retry_queue.key, "-INF", Time.now.utc.to_f).each do |payload|
        # Remove.
        removed = redis.zrem(self.retry_queue.key, payload)
        # Ff it wasn't actually there to remove, it must've been taken by
        # another process/thread.
        next if ! removed

        succeeded = process_payload(payload)
        num_succeeded += 1 if succeeded
      end

      num_succeeded
    end

    # See: https://github.com/mperham/sidekiq/blob/master/lib/sidekiq/processor.rb
    def process_payload(payload)
      msg = JSON.parse(payload)
      klass = msg['class'].constantize
      args = msg['args']
      worker = klass.new
      # Clone the args in case the Worker changes them.
      cloned_args = args.duplicable? ? args.clone : args
      worker.perform(*cloned_args)
      true
    rescue Exception => e
      handle_exception(msg, e)
      false
    end

    def handle_exception(msg, e)
      msg['error_message'] = e.message
      msg['error_class'] = e.class.name
      count = if msg['retry_count']
        msg['retried_at'] = Time.now.utc
        msg['retry_count'] += 1
      else
        msg['failed_at'] = Time.now.utc
        msg['retry_count'] = 0
      end

      msg['backtrace'] = e.backtrace

      # Always retry.
      retry_at = Time.now.utc.to_f + 30
      redis.zadd(self.retry_queue.key, retry_at.to_s, JSON.generate(msg))
    end

  end

end
