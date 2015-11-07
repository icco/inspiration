require "bundler/setup"
require "padrino-core/cli/rake"

PadrinoTasks.use(:database)
PadrinoTasks.use(:none)

PadrinoTasks.init

task default: :test

desc "Run a local server."
task :local do
  Kernel.exec("shotgun -s thin -p 9393")
end
