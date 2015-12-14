require "bundler/setup"
require "./site"

task :default do
  puts "No tests written."
end

desc "Run a local server."
task :local do
  Kernel.exec("shotgun -s thin -p 9393")
end

desc "Update links."
task :cron do
  idb = ImageDB.new
  idb.update
end

desc "Get all old favorites."
task :get_old do
  idb = ImageDB.new
  idb.full_update
end

desc "Build a cache of the image db."
task :build_cache do
  cdb = CacheDB.new
  idb = ImageDB.new

  idb.images.to_a.shuffle.each do |i|
    cdb.cache i
  end

  cdb.clean idb.images
end

desc "Try to update 10 images in the cache."
task :build_cache_random do
  cdb = CacheDB.new
  idb = ImageDB.new

  idb.images.to_a.sample(10).each do |i|
    cdb.cache i
  end
end

desc "Remove unused images in cache."
task :clean do
  cdb = CacheDB.new
  idb = ImageDB.new

  cdb.clean idb.images
end

task :import_sqlite do
  cdb = CacheDB.new
  cdb.load_sql_to_json "cache.db"
end

desc "Download all images into a folder."
task :download do
  require 'open-uri'
  require 'uri'

  cdb = CacheDB.new
  cdb.all.map {|k, v| v["image"] }.each do |i|
    url = URI(i)
    filename = url.path.split('/').last
    
    open("tmp/images/#{filename}", 'wb') do |file|
      puts "Downloading #{filename}"
      file << open(url).read
    end
  end
end
