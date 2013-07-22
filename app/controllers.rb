Inspiration::App.controllers  do
  layout :main

  get :about, :cache => true do
    expires_in 3600 # 1 hr

    @text = partial :about

    render :about
  end

  get :index, :cache => true do
    expires_in 3600 # 1 hr

    @images = build_image_db.sample(100)

    render :index
  end

  get :all do
    @images = build_image_db

    render :index
  end
end

def build_image_db
  images = Set.new(File.readlines(Inspiration::LINK_FILE).map {|l| l.strip })
  rss_url = 'http://backend.deviantart.com/rss.xml?q=favby%3Acalvin166%2F1422412&type=deviation'
  open(rss_url) do |rss|
    feed = RSS::Parser.parse(rss)
    feed.items.each do |item|
      images.add item.link
    end
  end

  all_images = images.delete_if {|i| i.empty? }.to_a.sort
  File.open(Inspiration::LINK_FILE, 'w') {|file| file.write(all_images.to_a.join("\n")) }

  return all_images
end
