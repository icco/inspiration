# A class wrapper around the cache.json file. The file is a hash of objects.
# The key is the original url, the object contains information to render the
# image.
class CacheDB

  def initialize
    @cache = JSON.parse(File.read(Inspiration::CACHE_FILE))
  end

  def cache url
    dribbble_re = %r{http://dribbble\.com/shots/}
    deviant_re = %r{deviantart\.com}
    flickr_re = %r{www\.flickr\.com}

    case url
    when dribbble_re
      oembed_url = "https://api.dribbble.com/shots/#{url.gsub(dribbble_re, "")}"
      # p oembed_url

      resp = Faraday.get oembed_url
      if resp.status == 200
        data = JSON.parse(resp.body)
      else
        logger.error "Code #{resp.status}: Hitting #{oembed_url} for #{url}"
        return
      end

      title = "\"#{data["title"]}\" by #{data["player"]["name"]}"
      if data["image_400_url"]
        image_link = data["image_400_url"]
      else
        image_link = data["image_teaser_url"]
      end

      hash = {title: title, image: image_link, size: {width: data["width"], height: data["height"]}}
      @cache[url] = hash
    when deviant_re
      oembed_url = "https://backend.deviantart.com/oembed?url=#{URI.escape(url, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))}&format=json"
      # p oembed_url

      resp = Faraday.get oembed_url
      if resp.status == 200
        data = JSON.parse(resp.body)
      else
        logger.error "Code #{resp.status}: Hitting #{oembed_url} for #{url}"
        return
      end

      title = "\"#{data["title"]}\" by #{data["author_name"]}"
      hash = {title: title, image: data["thumbnail_url"], size: {width: data["width"], height: data["height"]}}
      @cache[url] = hash
    when flickr_re
      oembed_url = "https://www.flickr.com/services/oembed?url=#{URI.escape(url, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))}&format=json&&maxwidth=300"
      # p oembed_url
      #
      resp = Faraday.get oembed_url
      if resp.status == 200
        data = JSON.parse(resp.body)
      else
        logger.error "Code #{resp.status}: Hitting #{oembed_url} for #{url}"
        return
      end

      if !data["thumbnail_url"]
        logger.error "No Tumbnail: #{oembed_url}"
        return
      end

      image_url = data["thumbnail_url"].gsub(/\_s\./, "_n.")
      title = "\"#{data["title"]}\" by #{data["author_name"]}"
      hash = {title: title, image: image_url, size: {width: data["width"], height: data["height"]}}
      p hash
      @cache[url] = hash
    else
      logger.error "No idea what url this is: #{url}"
    end
  end

  def get url
    return @cache[url]
  end

  def write
    File.open(Inspiration::CACHE_FILE, 'w') {|f| f << JSON.pretty_generate(@cache) }
  end
end
