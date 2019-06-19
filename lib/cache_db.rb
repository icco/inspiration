# A class wrapper around the cache.json file. The file is a hash of objects.
# The key is the original url, the object contains information to render the
# image.
class CacheDB
  include Logging

  def initialize
    Oj.default_options = Inspiration::OJ_OPTIONS
    @cache_file_name = Inspiration::CACHE_FILE

    @keyfilter = %r{[\/:\.\\\-@]}

    if File.extname(@cache_file_name).eql? ".json"
      @mode = "json"
      unless File.exist? @cache_file_name
        File.open(@cache_file_name, "w+") { |file| file.write("{}") }
      end
    else
      raise "Invalid Cache Type!"
    end
  end

  def json?
    @mode == "json"
  end

  def sample(count)
    if json?
      file = Oj.load_file(@cache_file_name)
      file.values.sample(count).delete_if { |d| d.nil? || d["image"].nil? }
    end
  end

  def cache(url)
    return true unless needs_update? url

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
    else
      set url, hash
    end
  end

  def get(url)
    return nil if url.nil? || url.empty?

    key = url.gsub(@keyfilter, "")

    if json?
      data = Oj::Doc.open_file(@cache_file_name) { |doc| doc.fetch "/#{key}" }

      if data.eql? []
        return nil
      else
        return data
      end
    else
      return nil
    end
  end

  def set(url, data)
    key = url.gsub(@keyfilter, "")

    if json?
      file = all
      file[key] = data
      Oj.to_file(@cache_file_name, file, Oj.default_options)
    else
      return false
    end

    true
  end

  def delete(key)
    if json?
      file = all
      file.delete key
      Oj.to_file(@cache_file_name, file)
    else
      return false
    end

    true
  end

  def all
    Oj.load_file(@cache_file_name) if json?
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

  def clean(images)
    valid_keys = images.map { |i| i.gsub(@keyfilter, "") }.to_set
    current_keys = all.keys.to_set if json?
    to_delete = current_keys - valid_keys

    to_delete.each do |k|
      delete k
    end

    valid_keys.each do |k|
      data = get k
      next unless data
      delete k if data["image"].nil? || data["image"].empty?

      delete k if data["title"].nil? || data["title"].empty?
    end

    to_delete.count
  end
end
