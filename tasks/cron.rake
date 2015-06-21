desc "Update links."
task :cron => :environment do
  idb = ImageDb.new
  idb.update
end

desc "Get all old favorites."
task :get_old => :environment do
  idb = ImageDb.new
  idb.full_update
end

desc "Build a cache of the image db."
task :build_cache => :environment do
  cdb = CacheDB.new
  idb = ImageDb.new

  idb.images.to_a.shuffle.each do |i|
    cdb.cache i
  end

  cdb.write
end
