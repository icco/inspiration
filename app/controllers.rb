Inspiration::App.controllers  do
  get :index do
    @images = Set.new(File.readlines(Inspiration::LINK_FILE))
    rss_url = 'http://backend.deviantart.com/rss.xml?q=favby%3Acalvin166%2F1422412&type=deviation'
    open(rss_url) do |rss|
      feed = RSS::Parser.parse(rss)
      feed.items.each do |item|
        @images.add item.link
      end
    end

    File.open(Inspiration::LINK_FILE, 'w') {|file| file.write(@images.to_a.join("\n")) }

    render :index
  end
end
