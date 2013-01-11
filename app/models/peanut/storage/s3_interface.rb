require 'peanut/storage/interface'

module Peanut::Storage
  class S3Interface < Interface    

    # There should be an aws.yml file that looks like:
    #
    # development:
    #    access_key_id: REPLACE_WITH_ACCESS_KEY_ID
    #    secret_access_key: REPLACE_WITH_SECRET_ACCESS_KEY
    #    bucket: NAME_OF_S3_BUCKET_TO_PUT_EVERYTHING_INTO
    #
    # production:
    #    ...

    class << self

      def exists?(locator, options={})
        bucket.objects[locator].exists?
      end

      def read(locator, options = {})
        bucket.objects[locator].read
      end

      # Write the given data and returns the locator 
      # and url handles to the file. If no locator is passed, a new file is created.
      def write(data, options = {})
        
        locator = options[:key] || options[:locator]
        s3_options = options[:s3_options] || {}
        s3_options.merge!(:acl=>:public_read)

        if locator.nil? or locator.empty?
          new_file_name = options[:filename] ? sanitize_filename(options[:filename]) : Peanut::Toolkit.rand_string[0..15]
          new_file_name += '.' + s3_options[:extension] if s3_options[:extension]
          locator = "#{Time.new.tv_sec}#{new_file_name}"
        end

        obj = bucket.objects[locator]

        obj.write(data, s3_options)

        [locator, obj.public_url.to_s]
      end

      def delete(locator, options = {})
        bucket.objects[locator].delete
      end

      def bucket
        @@bucket ||= begin
          if config = YAML.load_file("#{Rails.root}/config/aws.yml") and config[Rails.env]
            bucket_id = config[Rails.env]['bucket']
          else
            bucket_id = 'deadbeef'
          end
          AWS::S3.new.buckets[bucket_id]
        end
      end

    end # /class methods
  end # /class
end # /module