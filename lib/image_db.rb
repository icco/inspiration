class ImageDb
  def initialize
    @images = Set.new(File.readlines(Inspiration::LINK_FILE).map {|l| l.strip })

    cache_contents = File.read(Inspiration::CACHE_FILE)
    if not cache_contents.empty?
      @cache = JSON.parse(cache_contents)
    else
      @cache = {}
    end
  end

  def images
    return @images.to_a
  end

  def update
    rss_url = 'http://backend.deviantart.com/rss.xml?q=favby%3Acalvin166%2F1422412&type=deviation'
    open(rss_url) do |rss|
      feed = RSS::Parser.parse(rss)
      feed.items.each do |item|
        @images.add item.link
      end
    end

    data = Dribbble::Base.paginated_list(Dribbble::Base.get("/players/icco/shots/likes", :query => {:per_page => 50}))
    data.map {|s| s.url }.each {|l| @images.add l }

    favorites = flickr.favorites.getPublicList(:user_id => '42027916@N00', :extras => 'url_n').map {|p| "http://www.flickr.com/photos/#{p["owner"]}/#{p["id"]}"}
    favorites.each {|l| @images.add l }

    all_images = @images.delete_if {|i| i.empty? }.to_a.sort
    File.open(Inspiration::LINK_FILE, 'w') {|file| file.write(all_images.to_a.join("\n")) }

    return true
  end

  def full_update
    (0..6000).step(60) do |offset|
      rss_url = "http://backend.deviantart.com/rss.xml?q=favby%3Acalvin166%2F1422412&type=deviation&offset=#{offset}"
      p ({ :deviant => "calvin166", :offset => offset })
      open(rss_url) do |rss|
        feed = RSS::Parser.parse(rss)
        feed.items.each do |item|
          @images.add item.link
        end
      end

      puts "Images: #{@images.count}"
    end

    dribbble_user = "icco"
    dribbble_per_page = 30
    page_count = Dribbble::Base.paginated_list(Dribbble::Base.get("/players/#{dribbble_user}/shots/likes", :query => {:per_page => dribbble_per_page})).pages
    (1..page_count).each do |page|
      p ({ :player => dribbble_user, :page => page })
      data = Dribbble::Base.paginated_list(Dribbble::Base.get("/players/#{dribbble_user}/shots/likes", :query => {:page => page, :per_page => dribbble_per_page}))
      array = data.map {|s| s.url }
      array.each {|l| @images.add l }

      puts "Images: #{@images.count}"
    end

    # http://www.flickr.com/services/api/misc.urls.html
    (1..25).each do |page|
      p ({ :flickr => '42027916@N00', :page => page })
      favorites = flickr.favorites.getPublicList(:user_id => '42027916@N00', :extras => 'url_n', :page => page).map {|p| "http://www.flickr.com/photos/#{p["owner"]}/#{p["id"]}"}
      favorites.each {|l| @images.add l }
      puts "Images: #{@images.count}"
    end

    @images = @images.delete_if {|i| i.empty? }.to_a.sort

    File.open(Inspiration::LINK_FILE, 'w') {|file| file.write(@images.to_a.join("\n")) }

    return true
  end

  def cache favorite_link, image_link
    if @images.exists? favorite_link
      @cache[favorite_link] = image_link
      write_cache
      return true
    end

    return false
  end

  def write_cache
    File.open(Inspiration::LINK_FILE, 'w') {|file| file.write(@cache.to_json) }
  end
end
