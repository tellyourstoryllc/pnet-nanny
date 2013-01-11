class Peanut::S3File < Peanut::ActivePeanut::Base
  self.abstract_class = true
    
  attr_accessor :data
  attr_accessible :name, :url

  def save
    if @data
      result = Peanut::Storage::S3Interface.write(@data)
      self.name = result[0]
      self.url = result[1]
      self.filesize = @data.length
      @data = nil
    end
    super
  end
  
  def delete
    self.delete_file
    super
  end
  
  def data
    @data ||= Peanut::Storage::S3Interface.read(self.name)
  end

  def delete_file
    if self.name
      Peanut::Storage::S3Interface.delete(self.name)
      self.name = nil
    end
  end

end