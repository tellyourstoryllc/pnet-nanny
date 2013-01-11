module Peanut::Storage
  class Interface

    def self.exists?(locator, options = {})
      false
    end

    def self.read(locator, options = {})
    end

    # Write the given data to the storage mechanism, and returns the locator 
    # and url handles to the file.
    def self.write(data, options = {})
    end

    def self.delete(locator, options = {})
    end

  end
end