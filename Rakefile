require 'bundler/setup'
require 'padrino-core/cli/rake'

PadrinoTasks.init

desc "Run a local server."
task :local do
  Kernel.exec("shotgun -s thin -p 9393")
end

desc "Get all old favorites."
task :get_old => :environment do
  puts Inspiration::LINK_FILE
  @images = Set.new(File.readlines(Inspiration::LINK_FILE).map {|l| l.strip })

  (0..6000).step(60) do |offset|
    rss_url = "http://backend.deviantart.com/rss.xml?q=favby%3Acalvin166%2F1422412&type=deviation&offset=#{offset}"
    puts rss_url
    open(rss_url) do |rss|
      feed = RSS::Parser.parse(rss)
      feed.items.each do |item|
        @images.add item.link
      end
    end

    puts "Images: #{@images.count}"
  end

  @images = @images.delete_if {|i| i.empty? }.to_a.sort

  File.open(Inspiration::LINK_FILE, 'w') {|file| file.write(@images.to_a.join("\n")) }
end
