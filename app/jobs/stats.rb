#!/usr/bin/env ruby
require 'rubygems'

conn = Photo.connection

total_photos = Photo.count_by_sql("select count(*) from photos where date(created_at) = date(now())")
UseLog.set("photos/total", total_photos)
['approved','deleted','rejected','unclear','pending'].each do |status|
  sql = "select count(*) from photos where status = '#{status}' and date(created_at) = date(now())"
  result = conn.select_value(sql)
  UseLog.set("photos/#{status}", result.to_i)
  UseLog.set("photos/#{status}_percent", (result.to_f / total_photos.to_f * 10000))
end

conn = Vote.connection
sql = "select count(distinct(worker_id)) from photo_votes where date(created_at) = date(now())"
result = conn.select_value(sql)
UseLog.set('votes/unique_voters', result.to_i)

sql = "select count(*) from photo_votes where date(created_at) = date(now())"
result = conn.select_value(sql)
UseLog.set('votes/total', result.to_i)

#log_conn = UseLog::
Vote.prune
Photo.prune