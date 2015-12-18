class ImageDB
  include Logging

  def initialize
    @images = Set.new(File.readlines(Inspiration::LINK_FILE).map(&:strip))
  end

  def images
    @images.to_a
  end

  def sample(count)
    images.sample count
  end

  def self.instagram_client
    Instagram.client(access_token: Inspiration::INSTAGRAM_TOKEN)
  end

  def self.twitter_client
    Twitter::REST::Client.new(Inspiration::TWITTER_CONFIG)
  end

  # This goes through all services and stores the newest links.
  #
  # NOTE: When updating this, make sure to update the method full_update as well.
  def update
    # DeviantArt
    rss_url = "https://backend.deviantart.com/rss.xml?q=favby%3Acalvin166%2F1422412&type=deviation"
    open(rss_url) do |rss|
      feed = RSS::Parser.parse(rss)
      feed.items.each do |item|
        @images.add item.link
      end
    end

    # Write all image links to disk
    all_images = @images.delete_if(&:empty?).to_a.sort
    File.open(Inspiration::LINK_FILE, "w") { |file| file.write(all_images.join("\n")) }

    # Dribbble
    user = Dribbble::User.find(Inspiration::DRIBBBLE_TOKEN, "icco")
    data = user.likes
    data.each { |l| @images.add l.html_url }

    # Write all image links to disk
    all_images = @images.delete_if(&:empty?).to_a.sort
    File.open(Inspiration::LINK_FILE, "w") { |file| file.write(all_images.join("\n")) }

    # Flickr
    favorites = flickr.favorites.getPublicList(user_id: "42027916@N00", extras: "url_n")
    favorites = favorites.map { |p| "https://www.flickr.com/photos/#{p['owner']}/#{p['id']}" }
    favorites.each { |l| @images.add l }

    # Write all image links to disk
    all_images = @images.delete_if(&:empty?).to_a.sort
    File.open(Inspiration::LINK_FILE, "w") { |file| file.write(all_images.join("\n")) }

    # VeryGoods.co
    products = open "https://verygoods.co/site-api-0.1/users/icco/goods?limit=20" do |j|
      data = Oj.compat_load(j)
      data["_embedded"]["goods"].map do |g|
        "https://verygoods.co/site-api-0.1#{g['_links']['product']['href']}"
      end
    end
    products.each { |prod| @images.add prod }

    # Write all image links to disk
    all_images = @images.delete_if(&:empty?).to_a.sort
    File.open(Inspiration::LINK_FILE, "w") { |file| file.write(all_images.join("\n")) }

    # Instagram
    ImageDB.instagram_client.user_liked_media.each do |i|
      @images.add i.link
    end

    # Write all image links to disk
    all_images = @images.delete_if(&:empty?).to_a.sort
    File.open(Inspiration::LINK_FILE, "w") { |file| file.write(all_images.join("\n")) }

    # Twitter
    begin
      ImageDB.twitter_client.favorites("icco", count: 200).each do |t|
        if t.user.screen_name.eql? "archillect"
          @images.add t.uri.to_s
        end
      end
    rescue Twitter::Error::TooManyRequests => e
      logging.warn "Twitter rate limit hit. Sleeping for #{e.rate_limit.reset_in + 1}"
      sleep e.rate_limit.reset_in + 1
      retry
    end

    # Write all image links to disk
    all_images = @images.delete_if(&:empty?).to_a.sort
    File.open(Inspiration::LINK_FILE, "w") { |file| file.write(all_images.join("\n")) }

    true
  end

  # This goes through all services and stores the links.
  #
  # NOTE: When updating this, make sure to update the method update as well.
  def full_update
    # Flickr Personal Favorites Set
    # NOTE: Page count verified 2015-07-22
    (1..3).each do |page|
      print_data = { flickr: "42027916@N00", set: "72157601200827657", page: page }
      logging.info print_data.inspect
      begin
        resp = flickr.photosets.getPhotos(photoset_id: "72157601200827657", extras: "url_n", page: page)
        favorites = resp["photo"].map { |p| "https://www.flickr.com/photos/#{resp['owner']}/#{p['id']}" }
        favorites.each { |l| @images.add l }
        logging.info "Images: #{@images.count}"
      rescue
        logging.error "Failed to get."
      end
    end

    # Write to file.
    File.open(Inspiration::LINK_FILE, "w") { |file| file.write(@images.to_a.join("\n")) }

    # DA Favorites
    # NOTE: Offset count verified 2015-07-22
    (0..6000).step(60) do |offset|
      rss_url = "https://backend.deviantart.com/rss.xml?q=favby%3Acalvin166%2F1422412&type=deviation&offset=#{offset}"
      print_data = { deviant: "calvin166", offset: offset }
      logging.info print_data.inspect
      open(rss_url) do |rss|
        feed = RSS::Parser.parse(rss)
        feed.items.each do |item|
          @images.add item.link
        end
      end

      logging.info "Images: #{@images.count}"
    end

    # Write to file.
    File.open(Inspiration::LINK_FILE, "w") { |file| file.write(@images.to_a.join("\n")) }

    # Dribbble
    # NOTE: Page count verified 2015-09-02
    dribbble_user = "icco"
    page_count = 30

    (1..page_count).each do |page|
      user = Dribbble::User.find(Inspiration::DRIBBBLE_TOKEN, "icco")
      data = user.likes page: page
      print_data = { player: dribbble_user, page: page }
      logging.info print_data.inspect
      data.each { |l| @images.add l.html_url }

      logging.info "Images: #{@images.count}"
    end

    # Write to file.
    File.open(Inspiration::LINK_FILE, "w") { |file| file.write(@images.to_a.join("\n")) }

    # Flickr Favorites
    # http://www.flickr.com/services/api/misc.urls.html
    # NOTE: Page count verified 2015-07-22
    (1..30).each do |page|
      print_data = { flickr: "42027916@N00", page: page }
      logging.info print_data.inspect

      favorites = flickr.favorites.getPublicList(user_id: "42027916@N00", extras: "url_n", page: page)
      favorites = favorites.map { |p| "https://www.flickr.com/photos/#{p['owner']}/#{p['id']}" }
      favorites.each { |l| @images.add l }
      logging.info "Images: #{@images.count}"
    end

    # Write to file.
    File.open(Inspiration::LINK_FILE, "w") { |file| file.write(@images.to_a.join("\n")) }

    # VeryGoods.co
    domain = "https://verygoods.co/site-api-0.1"
    url = domain + "/users/icco/goods?limit=20"
    while url
      print_data = { verygoods: url }
      logging.info print_data.inspect

      j = open url
      data = Oj.compat_load(j)
      if data["_links"]["next"]
        url = domain + data["_links"]["next"]["href"]
      else
        url = nil
      end

      products = data["_embedded"]["goods"].map do |g|
        "https://verygoods.co#{g['_links']['product']['href'].gsub(/products/, 'product')}"
      end
      products.each { |prod| @images.add prod }
      logging.info "Images: #{@images.count}"
    end

    # Write to file.
    File.open(Inspiration::LINK_FILE, "w") { |file| file.write(@images.to_a.join("\n")) }

    # Instagram
    #
    # No idea if the max_id stuff works here, all instagram likes currently fit
    # in one page.
    max_id = nil
    user = ImageDB.instagram_client.user.username
    loop do
      print_data = { instagram: user, max_id: max_id }
      logging.info print_data.inspect

      args = { max_like_id: max_id }.delete_if { |_k, v| v.nil? }
      data = ImageDB.instagram_client.user_liked_media(args)
      data.each do |i|
        @images.add i.link
        max_id = i.id
      end

      logging.info "Images: #{@images.count}"
      break if data.count == 0
    end

    # Twitter
    options = { count: 20 }
    twitter_collect_with_max_id do |t_max_id|
      options[:max_id] = t_max_id unless t_max_id.nil?
      print_data = { twitter: "icco", max_id: t_max_id, images: @images.count }
      logging.info print_data.inspect
      begin
       ImageDB.twitter_client.favorites(options).each do |t|
          if t.user.screen_name.eql? "archillect"
            @images.add t.uri.to_s
          end
        end
      rescue Twitter::Error::TooManyRequests => e
        logging.warn "Twitter rate limit hit. Sleeping for #{e.rate_limit.reset_in + 1}"
        sleep e.rate_limit.reset_in + 1
        retry
      end
    end

    # Clean UP.
    @images = @images.delete_if(&:empty?).to_a.sort

    # Write to file.
    File.open(Inspiration::LINK_FILE, "w") { |file| file.write(@images.to_a.join("\n")) }

    true
  end

  def twitter_collect_with_max_id(collection = [], max_id = nil, &block)
    response = yield(max_id)
    collection += response
    response.empty? ? collection.flatten : twitter_collect_with_max_id(collection, response.last.id - 1, &block)
  rescue TypeError => e
    logging.error "Type Error: #{e.inspect}"
  end
end
