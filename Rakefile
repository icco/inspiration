require 'bundler/setup'
require 'padrino-core/cli/rake'

PadrinoTasks.init

desc "Run a local server."
task :local do
  Kernel.exec("shotgun -s thin -p 9393")
end

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
