require 'bundler/setup'
require 'padrino-core/cli/rake'

PadrinoTasks.init

desc "Run a local server."
task :local do
    Kernel.exec("shotgun -s thin -p 9393")
end
