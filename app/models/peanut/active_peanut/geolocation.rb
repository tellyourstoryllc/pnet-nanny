module Peanut::ActivePeanut::Geolocation
  extend Math

  DEG_TO_RAD = 0.0174532925

  def self.included(klass)
    klass.send(:attr_accessible, :latitude)
    klass.send(:attr_accessible, :longitude)
    klass.extend(ClassMethods)
  end

  def location
    if lat = self.latitude and lon = self.longitude
      Peanut::Location.new(lat,lon)
    end
  end
  
  def location=(*loc)
    case loc
    when Location
      self.latitude = Location.latitude
      self.longitude = Location.longitude
    when Array
      self.latitude = loc[0]
      self.longitude = loc[1]
    else
      self.latitude = 0.0
      self.longitude = 0.0
    end
  end

  # Distance of the location from the given coordinates
  def distance_from(target_lat, target_lon)
    lat_rad = self.latitude * DEG_TO_RAD
    target_lat_rad = target_lat * DEG_TO_RAD
    lon_rad = self.longitude * DEG_TO_RAD
    target_lon_rad = target_lon * DEG_TO_RAD
    
    delta_lat = target_lat_rad - lat_rad
    delta_lon = target_lon_rad - lon_rad
    
    a = (Math.sin(delta_lat / 2) ** 2) + Math.cos(target_lat_rad)*Math.cos(lat_rad)*(Math.sin(delta_lon/2) ** 2)
    dist = 3956 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))
  end
  
  module ClassMethods

    def coordinate_where_options(latitude, longitude, options={})
      options[:distance] ||= 5

      delta_lat = options[:distance] / 69.0
      delta_lon = options[:distance] / (Math.cos(latitude * DEG_TO_RAD) * 69).abs

      n_lat = latitude - delta_lat
      x_lat = latitude + delta_lat
      n_lon = longitude - delta_lon
      x_lon = longitude + delta_lon
      
      # Round to 3 decimal places
      n_lat = (n_lat*1000).round.to_f / 1000
      x_lat = (x_lat*1000).round.to_f / 1000
      n_lon = (n_lon*1000).round.to_f / 1000
      x_lon = (x_lon*1000).round.to_f / 1000

      { :latitude => n_lat..x_lat, :longitude => n_lon..x_lon }
    end

    def coordinate_order_options(latitude, longitude)
      <<-CODE
        3958.755864232 * 2 * 
        ASIN(SQRT(POWER(SIN((#{latitude} - latitude) * PI() / 180 / 2), 2) + 
        COS(#{latitude} * PI() / 180) * COS(latitude * PI() / 180) * 
        POWER(SIN((#{longitude} - longitude) * PI() / 180 / 2), 2) ))
      CODE
    end

    def find_nearest_coordinates(latitude, longitude, options={})
      results = self.where(self.coordinate_where_options(latitude, longitude, options))      
      results = results.order(coordinate_order_options(latitude, longitude)) if options[:order]
      results
    end   
  end
end
