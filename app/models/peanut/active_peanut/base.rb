require 'redis'
require 'redis/counter'
require 'peanut/redis/connection'

module Peanut
  module ActivePeanut
    class Base < ActiveRecord::Base

      include ::Peanut::Redis::Connection
      include ::Peanut::GeneralLog

      self.abstract_class = true # <--- This line MUST be first!!

      class_attribute :json_object_type_name

      def self.json_object_type
        self.json_object_type_name || self.name.downcase.gsub(':','_')
      end

      def ==(other_obj)
        if other_obj.class == self.class
          other_obj.id == self.id
        else
          super
        end
      end

      before_save :do_before_save

      def do_before_save
        self[:created_at] ||= Time.now.utc if self.respond_to?(:created_at)
      end

      alias_method :destroy_without_peanut, :destroy

      def delete
        if self.respond_to?(:status)
          self.status = 'deleted'
          self.save
        else
          self.destroy_without_peanut
        end
      end
      
      def destroy
        self.delete
      end

      # pan- a combining form meaning “all,” occurring originally in loanwords from Greek ( panacea; panoply ), but now used freely as a general
      # formative ( panleukopenia; panorama; pantelegraph; pantheism; pantonality ), and especially in terms, formed at will, implying the union
      # of all branches of a group ( Pan-Christian; Panhellenic; Pan-Slavism ). The hyphen and the second capital tend with longer use to be
      # lost, unless they are retained in order to set off clearly the component parts.           
      def pan_attribute_names
        self.respond_to?(:redis_attribute_names) ? attribute_names + redis_attribute_names : attribute_names
      end

      def pan_attributes
        hash = {}
        pan_attribute_names.each do |name|
          hash[name] = self.send(name.to_sym)
        end
        hash
      end
      
      def to_s
        "#{super}:#{pan_attributes}"
      end

      def as_json(options={})
        unless self.respond_to?(:status) and self.status == 'deleted'
          non_nil_attr_hash = self.pan_attributes.reject { |k,v| k =~ /^_/ } # Do not include attributes that start with an underscore
        else
          non_nil_attr_hash = self.pan_attributes.select { |k,v| %w(id status created_at).include?(k.to_s) } # Do not include attributes that start with an underscore
        end
        non_nil_attr_hash.reject! { |k,v| v.nil? } unless options[:include_nils]
        non_nil_attr_hash.merge({'object_type' => options[:object_type] || self.class.json_object_type })
      end
      
      # Random useful methods      
      def set_attribute(attribute, value)  
        self.send("#{attribute}=".to_sym, value)
      end

      def set_attribute_if(attribute, value, &block)  
        return if attribute.to_sym == :id # Don't allow id to be set this way.
        self.send("#{attribute}=".to_sym, value) if yield
      end
      
    end
  end
end
