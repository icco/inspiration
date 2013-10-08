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
