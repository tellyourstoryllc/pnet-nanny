ROOT = File.expand_path(File.dirname(__FILE__)+'/../../')
project = File.basename(ROOT)
munin_name = "#{project}_queue"

if ARGV[0] == 'config'

puts <<-TEXT
graph_title queue on #{project}
graph_vlabel count
#{munin_name}.label photos
#{munin_name}.type GAUGE
#{munin_name}.min 0
TEXT

else
  puts "#{munin_name}.value #{Photo.count(:conditions=>"status = 'pending'")}"
end
