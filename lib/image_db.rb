class ImageDB
  def initialize
    @images = Set.new(File.readlines(Inspiration::LINK_FILE).map {|l| l.strip })
  end

  def images
    return @images.to_a
  end

  def sample count
    return self.images.sample count
  end

  def update

    # DeviantArt
    rss_url = 'http://backend.deviantart.com/rss.xml?q=favby%3Acalvin166%2F1422412&type=deviation'
    open(rss_url) do |rss|
      feed = RSS::Parser.parse(rss)
      feed.items.each do |item|
        @images.add item.link
      end
    end

    # Dribbble
    data = Dribbble::Base.paginated_list(Dribbble::Base.get("/players/icco/shots/likes", :query => {:per_page => 50}))
    data.map {|s| s.url }.each {|l| @images.add l }

    # Flickr
    favorites = flickr.favorites.getPublicList(:user_id => '42027916@N00', :extras => 'url_n').map {|p| "http://www.flickr.com/photos/#{p["owner"]}/#{p["id"]}"}
    favorites.each {|l| @images.add l }

    # Write all image links to disk
    all_images = @images.delete_if {|i| i.empty? }.to_a.sort
    File.open(Inspiration::LINK_FILE, 'w') {|file| file.write(all_images.to_a.join("\n")) }

    # VeryGoods.co
    products = open 'https://verygoods.co/site-api-0.1/users/icco/goods?limit=20' do |j|
      data = Oj.compat_load(j)
      data["_embedded"]["goods"].map {|g| "https://verygoods.co/site-api-0.1#{g["_links"]["product"]["href"]}" }
    end
    products.each {|p| @images.add p }

    return true
  end

  def full_update

    # Flickr Personal Favorites Set
    # NOTE: Page count verified 2015-07-22
    (1..3).each do |page|
      p ({ :flickr => '42027916@N00', :set => '72157601200827657', :page => page })
      begin
        resp = flickr.photosets.getPhotos(:photoset_id => '72157601200827657', :extras => 'url_n', :page => page)
        favorites = resp["photo"].map {|p| "http://www.flickr.com/photos/#{resp["owner"]}/#{p["id"]}"}
        favorites.each {|l| @images.add l }
        puts "Images: #{@images.count}"
      rescue
        puts "Failed to get."
      end
    end

    # DA Favorites
    # NOTE: Offset count verified 2015-07-22
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
    dribbble_per_page = 50
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
    # NOTE: Page count verified 2015-07-22
    (1..30).each do |page|
      p ({ :flickr => '42027916@N00', :page => page })
      favorites = flickr.favorites.getPublicList(:user_id => '42027916@N00', :extras => 'url_n', :page => page).map {|p| "http://www.flickr.com/photos/#{p["owner"]}/#{p["id"]}"}
      favorites.each {|l| @images.add l }
      puts "Images: #{@images.count}"
    end

    # VeryGoods.co
    domain = "https://verygoods.co/site-api-0.1"
    url = domain + "/users/icco/goods?limit=20"
    while url do
      p ({ :verygoods => url })
      j = open url
      data = Oj.compat_load(j)
      if data["_links"]["next"]
        url = domain + data["_links"]["next"]["href"]
      else
        url = nil
      end
      products = data["_embedded"]["goods"].map {|g| domain + g["_links"]["product"]["href"] }
      products.each {|p| @images.add p }
      puts "Images: #{@images.count}"
    end

    # Clean UP.
    @images = @images.delete_if {|i| i.empty? }.to_a.sort

    # Write to file.
    File.open(Inspiration::LINK_FILE, 'w') {|file| file.write(@images.to_a.join("\n")) }

    return true
  end
end
