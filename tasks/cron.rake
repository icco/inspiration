desc "Update links."
task :cron => :environment do
  idb = ImageDB.new
  idb.update
end

desc "Get all old favorites."
task :get_old => :environment do
  idb = ImageDB.new
  idb.full_update
end

desc "Build a cache of the image db."
task :build_cache => :environment do
  cdb = CacheDB.new
  idb = ImageDB.new

  idb.images.to_a.shuffle.each do |i|
    cdb.cache i
  end

  cdb.clean idb.images
end

desc "Try to update 10 images in the cache."
task :build_cache_random => :environment do
  cdb = CacheDB.new
  idb = ImageDB.new

  idb.images.to_a.sample(10).each do |i|
    cdb.cache i
  end
end

desc "Remove unused images in cache."
task :clean => :environment do
  cdb = CacheDB.new
  idb = ImageDB.new

  cdb.clean idb.images
end

task :import_sqlite => :environment do
  cdb = CacheDB.new
  cdb.load_sql_to_json "cache.db"
end
