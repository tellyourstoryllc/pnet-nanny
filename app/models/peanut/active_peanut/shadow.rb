module Peanut
  module ActivePeanut
    class Shadow < Peanut::ActivePeanut::Base

      self.abstract_class = true

      def self.inherited(klass)
        super
        klass.cattr_accessor :shadowcaster
      end

      def self.from(obj)
        if obj.class == self.shadowcaster
          shadow = self.find_or_create_by_id(obj.id)
          shadow.cast_from(obj)
          shadow
        else
          raise RuntimeError.new("Unable to cast shadow for #{obj.class} onto #{self}. Should be #{self.shadowcaster}")
        end
      end

      def source
        @source ||= self.class.shadowcaster.send('find_by_id', self.id) if self.id
      end

      def cast_from(source_obj)
        @source = source_obj
        self.copy_attributes_from(source_obj)
        self.derive_attributes_from(source_obj)
        self.save
      end

      # Default behavior copies over attributes with the same name.
      def copy_attributes_from(peanut)
        (self.pan_attribute_names & peanut.pan_attribute_names).each do |attribute|
          self.send("#{attribute}=", peanut.send(attribute))
        end
      end

      def derive_attributes_from(peanut)
        # Subclasses should implement this.
      end

    end
  end
end