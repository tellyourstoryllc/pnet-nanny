# Hodgepodge of random utility methods

require 'digest/md5'

module Peanut
  
  class Toolkit

    class << self

      def hash(any_object)
        case any_object
        when String
          Digest::MD5.hexdigest(any_object) 
        else
          Digest::MD5.hexdigest(Marshal::dump(any_object)) 
        end unless any_object.nil?
      end
      
      def salty_hash(any_object, salt = nil)
        salt ||= "_peanut_"
        case any_object
        when String
          Digest::MD5.hexdigest(any_object + salt) 
        else
          Digest::MD5.hexdigest(Marshal::dump(any_object) + salt) 
        end unless any_object.nil?
      end
      
      def rand_string(seed=nil)
        seed ? self.hash(rand.to_s + self.hash(seed).to_s) : self.hash(rand.to_s)
      end

      # Generates a random string from a set of easily readable characters
      # Stolen from http://stackoverflow.com/questions/88311/how-best-to-generate-a-random-string-in-ruby/493230#493230
      def activation_code(size = 6)
        charset = %w{A C D E F G H J K L M N P Q R T V W X Y Z}
        (0...size).map{ charset.to_a[rand(charset.size)] }.join
      end
      
      # Is the given string a valid email address?
      def is_email?(some_string)
        !(some_string =~ /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i).nil?
      end

      def find_urls(some_string)
        pattern = %r{((ftp|http|https|gopher|mailto|news|nntp|telnet|wais|file|prospero|aim|webcal):(([A-Za-z0-9$_.+!*(),;/?:@&~=-])|%[A-Fa-f0-9]{2}){2,}(#([a-zA-Z0-9][a-zA-Z0-9$_.+!*(),;/?:@&~=%-]*))?([A-Za-z0-9$_+!*();/?:~-]))}
        results = []
        some_string.split(/[\s="']+/).each do |string|
          if is_match = string =~ pattern
            results << $1
          end
        end
        results
      end
      
      # The following time methods are provided by rails as helpers, and so are not available to controllers and models. (boo!)
  
      def time_ago_in_words(time, include_seconds = false)
        distance_of_time_in_words(time, Time.now, include_seconds)
      end
      
      def distance_of_time_in_words(from_time, to_time = 0, include_seconds = false)
        from_time = from_time.to_time if from_time.respond_to?(:to_time)
        to_time = to_time.to_time if to_time.respond_to?(:to_time)
        distance_in_minutes = (((to_time - from_time).abs)/60).round
        distance_in_seconds = ((to_time - from_time).abs).round

        case distance_in_minutes
        when 0..1 
          return (distance_in_minutes == 0) ? 'less than a minute' : '1 minute' unless include_seconds
          "#{distance_in_seconds} seconds"
        when 2..44           then "#{distance_in_minutes} minutes"
        when 45..89          then 'about 1 hour'
        when 90..1439        then "about #{(distance_in_minutes.to_f / 60.0).round} hours"
        when 1440..2879      then '1 day'
        when 2880..43199     then "#{(distance_in_minutes / 1440).round} days"
        when 43200..86399    then 'about 1 month'
        when 86400..525959   then "#{(distance_in_minutes / 43200).round} months"
        when 525960..1051919 then 'about 1 year'
        else                      "over #{(distance_in_minutes / 525960).round} years"
        end
      end
      
    end
  end
end