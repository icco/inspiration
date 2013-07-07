Inspiration::App.controllers  do
  get :index, :cache => true do
    expires_in 3600 # 1 hr

    @images = Set.new(File.readlines(Inspiration::LINK_FILE).map {|l| l.strip })
    rss_url = 'http://backend.deviantart.com/rss.xml?q=favby%3Acalvin166%2F1422412&type=deviation'
    open(rss_url) do |rss|
      feed = RSS::Parser.parse(rss)
      feed.items.each do |item|
        @images.add item.link
      end
    end

    all_images = @images.delete_if {|i| i.empty? }.to_a.sort
    @images = all_images.sample(300)

    File.open(Inspiration::LINK_FILE, 'w') {|file| file.write(all_images.to_a.join("\n")) }

    render :index
  end
end
