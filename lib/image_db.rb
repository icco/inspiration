# frozen_string_literal: true

class ImageDB
  include Logging

  def initialize
    @bigquery = Google::Cloud::Bigquery.new project: "icco-cloud"
    Oj.default_options = Inspiration::OJ_OPTIONS
    @per_page = Inspiration::PER_PAGE
  end

  def count
    query = "SELECT count(*) as cnt FROM `icco-cloud.inspiration.cache`"
    data = @bigquery.query query
    data.first[:cnt].to_i
  end

  def page(n)
    query = "SELECT * FROM `icco-cloud.inspiration.cache` ORDER BY rand() * EXTRACT(DAYOFYEAR FROM CURRENT_DATE()) LIMIT @per_page OFFSET @offset"
    @bigquery.query query, params: { per_page: @per_page, offset: @per_page * n.to_i }
  end

  def get(url)
    query = "SELECT * FROM `icco-cloud.inspiration.cache` WHERE url = @url LIMIT 1"
    data = @bigquery.query query, params: { url: url }
    data.first
  end

  def needs_update?(data)
    return true if data.nil?

    return true if data["modified"].nil?

    # For Flickr wrong size stuff
    return true if data["image"].nil? || data["image"].match(/_q/)

    return true unless data["modified"].is_a? String

    # ~10 days * a random float
    time = Time.parse(data["modified"])
    (Time.now.utc - time) > (860_000 * rand)
  end

  def bulk_get(urls)
    query = "SELECT * FROM `icco-cloud.inspiration.cache` WHERE url IN UNNEST(@urls)"
    @bigquery.query query, params: { urls: urls }
  end

  def bulk_needs_update?(urls)
    bulk_get(urls).map {|d| d[:update] = needs_update? d; d }
  end

  def valid_twitter_users
    %w[
      1041uuu
      CloudyConway
      EveningWaters
      FFD8FFDB
      IGeometryArt
      MoMARobot
      PastPostcard
      _OutToSea_
      archillect
      artfinderlatest
      artmxsphere
      butdoesitfloat
      cooperhewittbot
      dscovr_epic
      everycolorbot
      ftrain
      interior
      jgilleard
      madeofsparrows
      mattahan
      moon_rise_bot
      softlandscapes
      tinyspires
      unsplash
      youtubeartifact
    ].map(&:downcase)
  end

  def self.instagram_client
    Instagram.client(access_token: Inspiration::INSTAGRAM_TOKEN, scope: "public_content")
  end

  def self.twitter_client
    Twitter::REST::Client.new(Inspiration::TWITTER_CONFIG)
  end

  def add(image_url)
    bulk_add [image_url]
  end

  def bulk_add image_urls
    needs = bulk_needs_update? image_urls
    image_urls.delete_if do |u|
      match = needs.select {|e| e.url == u }
      match.size > 0 && !match.first[:update]
    end

    dataset = @bigquery.dataset "inspiration", skip_lookup: true
    table = dataset.table "cache", skip_lookup: true
    table.insert image_urls.map {|u| cache u }
  end

  # This goes through all services and stores the newest links.
  def update
    # Flickr Personal Favorites Set
    # NOTE: Page count verified 2015-07-22
    (1...3).each do |page|
      print_data = { flickr: "42027916@N00", set: "72157601200827657", page: page, images: count }
      logging.info print_data.inspect
      begin
        resp = flickr.photosets.getPhotos(photoset_id: "72157601200827657", extras: "url_n", page: page)
        favorites = resp["photo"].map { |p| "https://www.flickr.com/photos/#{resp["owner"]}/#{p["id"]}" }
        bulk_add favorites
      rescue StandardError
        logging.error "Failed to get."
      end
    end

    # DA Favorites
    # NOTE: Offset count verified 2015-07-22
    (0..6000).step(60) do |offset|
      rss_url = "https://backend.deviantart.com/rss.xml?q=favby%3Acalvin166%2F1422412&type=deviation&offset=#{offset}"
      print_data = { deviant: "calvin166", offset: offset, images: count }
      logging.info print_data.inspect
      open(rss_url) do |rss|
        feed = RSS::Parser.parse(rss)
        bulk_add feed.items.map do |item|
          item.link
        end
      end
    end

    # Flickr Favorites
    # http://www.flickr.com/services/api/misc.urls.html
    # NOTE: Page count verified 2015-07-22
    (1..30).each do |page|
      print_data = { flickr: "42027916@N00", page: page, images: count }
      logging.info print_data.inspect

      favorites = flickr.favorites.getPublicList(user_id: "42027916@N00", extras: "url_n", page: page)
      favorites = favorites.map { |p| "https://www.flickr.com/photos/#{p["owner"]}/#{p["id"]}" }
      bulk_add favorites
    end

    # VeryGoods.co
    domain = "https://verygoods.co/site-api-0.1"
    url = domain + "/users/icco/goods?limit=20"
    while url
      print_data = { verygoods: url, images: count }
      logging.info print_data.inspect

      j = open url
      data = Oj.compat_load(j)
      url = (domain + data["_links"]["next"]["href"] if data["_links"]["next"])

      products = data["_embedded"]["goods"].map do |g|
        "https://verygoods.co#{g["_links"]["product"]["href"].gsub(/products/, "product")}"
      end
      bulk_add products
    end

    # Instagram
    #
    # No idea if the max_id stuff works here, all instagram likes currently fit
    # in one page.
    max_id = nil
    user = ImageDB.instagram_client.user.username
    loop do
      print_data = { instagram: user, max_id: max_id, images: count }
      logging.info print_data.inspect

      args = { max_like_id: max_id }.delete_if { |_k, v| v.nil? }
      data = ImageDB.instagram_client.user_liked_media(args)
      data.each do |i|
        add i.link
        max_id = i.id
      end
      break if data.count == 0
    rescue Instagram::BadRequest => e
      logging.warn "Instagram Bad Request: #{e}"
      break
    end

    # Twitter
    options = { count: 200 }
    twitter_collect_with_max_id do |t_max_id|
      options[:max_id] = t_max_id unless t_max_id.nil?
      print_data = { twitter: "icco", max_id: t_max_id, images: count }
      logging.info print_data.inspect
      begin
        ImageDB.twitter_client.favorites(options).each do |t|
          add t.uri.to_s if valid_twitter_users.include? t.user.screen_name.downcase
        end
      rescue Twitter::Error::TooManyRequests => e
        logging.warn "Twitter rate limit hit. Sleeping for #{e.rate_limit.reset_in + 1}"
        sleep e.rate_limit.reset_in + 1
        retry
      end
    end

    true
  end

  def twitter_collect_with_max_id(collection = [], max_id = nil, &block)
    response = yield(max_id)
    collection += response
    response.empty? ? collection.flatten : twitter_collect_with_max_id(collection, response.last.id - 1, &block)
  rescue TypeError => e
    logging.error "Type Error: #{e.inspect}"
  end

  def cache(url)
    hash = { url: url, modified: Time.now.utc.to_s }

    deviant_re = /deviantart\.com/
    flickr_re = /www\.flickr\.com/
    insta_re = %r{https://www.instagram\.com/p/}
    verygoods_re = /verygoods\.co/
    twitter_re = %r{https://twitter.com/}

    begin
      case url
      when deviant_re
        oembed_url = "https://backend.deviantart.com/oembed?url=#{URI.escape(url, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))}&format=json"
        resp = Typhoeus.get oembed_url, followlocation: true
        if resp.success?
          data = JSON.parse(resp.body)
        else
          logging.error "Code #{resp.response_code}: Hitting #{oembed_url} for #{url}"
          return
        end

        title = "\"#{data["title"]}\" by #{data["author_name"]}"
        attrs = { title: title, image: data["thumbnail_url"], size: { width: data["width"], height: data["height"] } }
        hash.merge! attrs
      when flickr_re
        oembed_url = "https://www.flickr.com/services/oembed?url=#{URI.escape(url, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))}&format=json&&maxwidth=400"
        resp = Typhoeus.get oembed_url, followlocation: true
        if resp.success?
          data = JSON.parse(resp.body)
        else
          logging.error "Code #{resp.response_code}: Hitting #{oembed_url} for #{url}"
          return
        end

        # Licenses are blocking embeding I think.
        if data["type"] == "link"
          # TODO: embed by scraping "/sizes/m/"
          logging.error "Flickr won't let us embed this: #{url}."
          return
        end

        unless data["url"]
          logging.error "No Tumbnail for #{url} at #{oembed_url}"
          return
        end

        image_url = data["url"]
        title = "\"#{data["title"]}\" by #{data["author_name"]}"
        attrs = { title: title, image: image_url, size: { width: data["width"], height: data["height"] } }
        hash.merge! attrs
      when insta_re
        # OEMBED for INSTAGRAM
        oembed_url = "https://api.instagram.com/oembed/?url=#{URI.escape(url, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))}"
        resp = Typhoeus.get oembed_url, followlocation: true
        if resp.success?
          data = JSON.parse(resp.body)
        else
          logging.error "Code #{resp.response_code}: Hitting #{oembed_url} for #{url}"
          return
        end

        title = "\"#{data["title"]}\" by #{data["author_name"]}"
        attrs = { title: title, image: data["thumbnail_url"], size: { width: data["thumbnail_width"], height: data["thumbnail_height"] } }
        hash.merge! attrs
      when verygoods_re
        # VeryGoods does not support OEmbed as of 2015-08-10
        oembed_url = "https://verygoods.co/site-api-0.1"
        oembed_url += URI(url).path.gsub(/product/, "products")
        resp = Typhoeus.get oembed_url, followlocation: true
        if resp.success?
          data = JSON.parse(resp.body)
        else
          logging.error "Code #{resp.response_code}: Hitting #{oembed_url} for #{url}"
          return
        end

        title = data["title"]
        image_url = data["medium_image_url"]
        size = { width: 400, height: nil } # TODO
        attrs = { title: title, image: image_url, size: size }
        hash.merge! attrs
      when twitter_re
        id = url.split("/").last
        client = ImageDB.twitter_client
        data = client.status(id)

        image = data.media.first
        title = "\"#{data.id}\" by @#{data.user.screen_name}"
        image_url = "#{image.media_url_https}:large"
        attrs = { title: title, image: image_url, size: { width: image.sizes[:large].w, height: image.sizes[:large].h } }
        hash.merge! attrs
      else
        logging.error "No idea what url this is: #{url}"
      end
    rescue StandardError => e
      logging.error "Failed OEmbed Get for #{url}: #{e.inspect}"
    rescue Twitter::Error::TooManyRequests => e
      logging.warn "Twitter rate limit hit. Sleeping for #{e.rate_limit.reset_in + 1}"
      sleep e.rate_limit.reset_in + 1
      retry
    end

    if hash[:title].nil? || hash[:title].empty? || hash[:image].nil? || hash[:image].empty?
      # Should we warn that we couldn't connect?
      nil
    else
      hash
    end
  end
end
