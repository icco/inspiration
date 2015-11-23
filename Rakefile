require "bundler/setup"

task :default do
  puts "No tests written."
end

desc "Run a local server."
task :local do
  Kernel.exec("shotgun -s thin -p 9393")
end
