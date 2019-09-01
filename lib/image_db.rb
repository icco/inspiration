class ImageDB
  include Logging

  def initialize
    @bigquery = Google::Cloud::Bigquery.new project: "icco-cloud"
    Oj.default_options = Inspiration::OJ_OPTIONS
  end

  def count
    query = "SELECT count(*) as cnt FROM `icco-cloud.inspiration.cache`"
    data = @bigquery.query query
    return data.first[:cnt].to_i
  end

  def page n
    query = "SELECT * FROM `icco-cloud.inspiration.cache` ORDER BY rand() LIMIT 200"
    @bigquery.query query
  end

  def valid_twitter_users
    %w(
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
    ).map(&:downcase)
  end

  def self.instagram_client
    Instagram.client(access_token: Inspiration::INSTAGRAM_TOKEN, scope: "public_content")
  end

  def self.twitter_client
    Twitter::REST::Client.new(Inspiration::TWITTER_CONFIG)
  end

  def add image_url
    image_blob = cache image_url
    dataset = @bigquery.dataset "inspiration", skip_lookup: true
    table = dataset.table "cache", skip_lookup: true

    if !image_blob.nil?
      table.insert [ image_blob ]
    end
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
        add item.link
      end
    end

    # Flickr
    favorites = flickr.favorites.getPublicList(user_id: "42027916@N00", extras: "url_n")
    favorites = favorites.map { |p| "https://www.flickr.com/photos/#{p["owner"]}/#{p["id"]}" }
    favorites.each { |l| @images.add l }

    # VeryGoods.co
    products = open "https://verygoods.co/site-api-0.1/users/icco/goods?limit=20" do |j|
      data = Oj.compat_load(j)
      data["_embedded"]["goods"].map do |g|
        "https://verygoods.co#{g["_links"]["product"]["href"].gsub(/products/, "product")}"
      end
    end
    products.each { |prod| add prod }


    # Instagram
    ImageDB.instagram_client.user_liked_media.each do |i|
      add i.link
    end

    # Twitter
    begin
      ImageDB.twitter_client.favorites("icco", count: 200).each do |t|
        if valid_twitter_users.include? t.user.screen_name.downcase
          add t.uri.to_s
        end
      end
    rescue Twitter::Error::TooManyRequests => e
      logging.warn "Twitter rate limit hit. Sleeping for #{e.rate_limit.reset_in + 1}"
      sleep e.rate_limit.reset_in + 1
      retry
    end

    true
  end

  def cache(url)
    return nil unless needs_update? url

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

    def needs_update?(url)
      data = get url

      return true if data.nil?

      return true if data["modified"].nil?

      # For Flickr wrong size stuff
      return true if data["image"].nil? || data["image"].match(/_q/)

      return true unless data["modified"].is_a? String

      # ~10 days * a random float
      time = Time.parse(data["modified"])
      (Time.now.utc - time) > (860_000 * rand)
    end
  end
end
