require "bundler/setup"
require "./site"

desc "Run a local server."
task :local do
  Kernel.exec("shotgun -s thin -p 9393")
end

desc "Update links."
task :update_some_links do
  idb = ImageDB.new
  idb.update
end
