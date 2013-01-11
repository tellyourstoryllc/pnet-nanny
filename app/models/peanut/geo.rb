class Geo < Peanut::ActivePeanut::Base
  
  extend Math  
  self.table_name = 'geo_data'
  DEG_TO_RAD = 0.0174532925
  
  class << self
    
    def find_nearest_coordinates(latitude, longitude, options={})
      
      options[:distance] ||= 5
      options[:limit] ||= 3

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
      
      # Peanut::Redis::Cache.capture(:vary=>[n_lat, x_lat, n_lon, x_lon, options[:limit]]) do
        if locations = find_by_sql("SELECT * from geo_data where latitude between #{n_lat} and #{x_lat}" +
          " and longitude between #{n_lon} and #{x_lon}")
          locations.sort { |a,b| a.distance_from(latitude, longitude) <=> b.distance_from(latitude, longitude) }[0..options[:limit]-1]
        end
      # end
    end   
    
    def name_for_coordinates(latitude, longitude, options={})

      if geos = Geo.find_nearest_coordinates(latitude, longitude, options) and location = geos[0]
        unless location[:region].empty? or location[:region] =~ /[0-9]+/
          return "#{location[:city]}, #{location[:region]}"
        else
          return location[:city]
        end
      else            
        return nil
      end
    end 
    
    def coordinates_for_name(name)

      found_location = PCache.capture(:vary=>name) do

        location = nil

        # First, look for zip code
        if name =~ /([0-9]{5})/
          zip = $1
          if geo = Geo.find(:first, :conditions=>['postal_code = ?', zip])
            location = [geo.latitude, geo.longitude]
          end
        end

        unless location
          results = {}
          weight = 0
          # Order in descending relevance.
          [ 'city', 'region' ].reverse_each do |col|
            weight += 1
            sub_weight = weight

            search_strings = name.split(',') + name.gsub(/[^a-zA-Z]/,' ').split(' ')
            search_strings.reverse_each do |token|
              sub_weight += 1
              if geos = Geo.find(:all, :conditions=>["#{col} like :token", {:token=>token.strip}])
                geos.each do |record|
                  if score = results[record.id]
                    results[record.id] = score + weight + sub_weight
                  else
                    results[record.id] = weight + sub_weight
                  end
                end 
              end
            end
          end

          # Favor US locations...
          if geos = Geo.find(:all, :conditions=>["country = 'US' and id in (?)", results.keys])
            geos.each do |record|
              if score = results[record.id]
                results[record.id] = score + 1
              else
                results[record.id] = 0
              end
            end 
          end

          # Pick the best result
          if results.size > 0
            geo_id = results.sort { |a,b| b[1] <=> a[1] }[0][0]
            geo = Geo.find(geo_id)
            location = [geo.latitude, geo.longitude]
          end
        end

        location
      end

      return found_location || [0,0]
    end
    
  end
  
  # Distance of the location from the given coordinates
  def distance_from(target_lat, target_lon)
    lat_rad = self[:latitude] * DEG_TO_RAD
    target_lat_rad = target_lat * DEG_TO_RAD
    lon_rad = self[:longitude] * DEG_TO_RAD
    target_lon_rad = target_lon * DEG_TO_RAD
    
    delta_lat = target_lat_rad - lat_rad
    delta_lon = target_lon_rad - lon_rad
    
    a = (Math.sin(delta_lat / 2) ** 2) + Math.cos(target_lat_rad)*Math.cos(lat_rad)*(Math.sin(delta_lon/2) ** 2)
    dist = 3956 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a))
  end
  
  def to_s
    "#{self[:id]} #{self[:city]}, #{self[:region]}, #{self[:country]} #{self[:postal_code]}"
  end
end