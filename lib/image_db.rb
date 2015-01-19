class ImageDb
  def initialize
    @images = Set.new(File.readlines(Inspiration::LINK_FILE).map {|l| l.strip })

    cache_contents = File.read(Inspiration::CACHE_FILE)
    begin
      if not cache_contents.empty?
        @cache = JSON.parse(cache_contents).delete_if {|a,b| a.empty? || b.empty? }
        write_cache
      else
        @cache = {}
      end
    rescue
      @cache = {}
    end
  end

  def images
    return @images.to_a
  end

  def sample count
    images = @images.to_a.delete_if {|i| cached? i }
    cached = @images.to_a.delete_if {|i| !cached? i }

    cached = cached.sample([count/2, cached.size].min)
    images = cached.sample([count/2, images.size, count-cached.size].min)

    return [images,cached]
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

    # Flickr Personal Favorites Set
    (1..3).each do |page|
      p ({ :flickr => '42027916@N00', :set => '72157601200827657', :page => page })
      begin
        favorites = flickr.photosets.getPhotos(:photoset_id => '72157601200827657', :extras => 'url_n', :page => page)["photo"].map {|p| "http://www.flickr.com/photos/#{p["owner"]}/#{p["id"]}"}
        favorites.each {|l| @images.add l }
        puts "Images: #{@images.count}"
      rescue
        puts "Failed to get."
      end
    end

    # DA Favorites
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

    # Dribbble
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

    # Flickr Favorites
    # http://www.flickr.com/services/api/misc.urls.html
    (1..30).each do |page|
      p ({ :flickr => '42027916@N00', :page => page })
      favorites = flickr.favorites.getPublicList(:user_id => '42027916@N00', :extras => 'url_n', :page => page).map {|p| "http://www.flickr.com/photos/#{p["owner"]}/#{p["id"]}"}
      favorites.each {|l| @images.add l }
      puts "Images: #{@images.count}"
    end

    @images = @images.delete_if {|i| i.empty? }.to_a.sort

    File.open(Inspiration::LINK_FILE, 'w') {|file| file.write(@images.to_a.join("\n")) }

    return true
  end

  def get_image favorite_link
    return @cache[favorite_link]
  end

  def cached? link
    return (not @cache[link].nil?)
  end

  def cache image_link, favorite_link
    if @images.include? favorite_link
      @cache[favorite_link] = image_link
      write_cache
      return true
    end

    return false
  end

  def write_cache
    File.open(Inspiration::CACHE_FILE, 'w') {|f| f << JSON.pretty_generate(@cache) }
  end
end
