class Peanut::Location
  
  extend Math
  DEG_TO_RAD = 0.0174532925
  
  attr_accessor :latitude
  attr_accessor :longitude

  def initialize(lat, lon)
    self.latitude = lat
    self.longitude = lon
  end
  
  # Distance of the location from the given coordinates
  def distance_from(other_location)
    target_lat = other_location.latitude
    target_lon = other_location.longitude
    lat_rad = self.latitude * DEG_TO_RAD
    target_lat_rad = target_lat * DEG_TO_RAD
    lon_rad = self.longitude * DEG_TO_RAD
    target_lon_rad = target_lon * DEG_TO_RAD
    
    delta_lat = target_lat_rad - lat_rad
    delta_lon = target_lon_rad - lon_rad
    
    a = (Math.sin(delta_lat / 2) ** 2) + Math.cos(target_lat_rad)*Math.cos(lat_rad)*(Math.sin(delta_lon/2) ** 2)
    dist = 3956 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))
  end
  
  def name
    Peanut::Geo.name_for_coordinates(self.latitude, self.longitude)
  end
  
end