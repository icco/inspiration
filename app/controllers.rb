Inspiration::App.controllers  do
  get :index do
    @images = []
    rss_url = 'http://backend.deviantart.com/rss.xml?q=favby%3Acalvin166%2F1422412&type=deviation'
    open(rss_url) do |rss|
      feed = RSS::Parser.parse(rss)
      feed.items.each do |item|
        @images.push item.link
      end
    end

    render :index
  end
end
