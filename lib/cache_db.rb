# A class wrapper around the cache.json file. The file is a hash of objects.
# The key is the original url, the object contains information to render the
# image.
class CacheDB

  def initialize
    @cache_file_name = Inspiration::CACHE_FILE
    @keyfilter = /[\/:\.]/
  end

  def cache url

    if !needs_update? url
      return true
    end

    dribbble_re = %r{http://dribbble\.com/shots/}
    deviant_re = %r{deviantart\.com}
    flickr_re = %r{www\.flickr\.com}

    case url
    when dribbble_re
      # Dribbble does not like us, go slow
      sleep 1

      oembed_url = "https://api.dribbble.com/shots/#{url.gsub(dribbble_re, "")}"
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

      hash = {title: title, image: image_link, size: {width: data["width"], height: data["height"]}, modified: Time.now}
      set url, hash
    when deviant_re
      oembed_url = "https://backend.deviantart.com/oembed?url=#{URI.escape(url, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))}&format=json"
      resp = Faraday.get oembed_url
      if resp.status == 200
        data = JSON.parse(resp.body)
      else
        logger.error "Code #{resp.status}: Hitting #{oembed_url} for #{url}"
        return
      end

      title = "\"#{data["title"]}\" by #{data["author_name"]}"
      hash = {title: title, image: data["thumbnail_url"], size: {width: data["width"], height: data["height"]}, modified: Time.now}
      set url, hash
    when flickr_re
      oembed_url = "https://www.flickr.com/services/oembed?url=#{URI.escape(url, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))}&format=json&&maxwidth=300"
      resp = Faraday.get oembed_url
      if resp.status == 200
        data = JSON.parse(resp.body)
      else
        logger.error "Code #{resp.status}: Hitting #{oembed_url} for #{url}"
        return
      end

      if !data["thumbnail_url"]
        logger.error "No Tumbnail for #{url} at #{oembed_url}"
        return
      end

      image_url = data["thumbnail_url"].gsub(/\_s\./, "_n.")
      title = "\"#{data["title"]}\" by #{data["author_name"]}"
      hash = {title: title, image: image_url, size: {width: data["width"], height: data["height"]}, modified: Time.now}
      set url, hash
    else
      logger.error "No idea what url this is: #{url}"
    end
  end

  def get url
    key = url.gsub(@keyfilter, '')
    return Oj::Doc.open_file(@cache_file_name) { |doc| doc.fetch "/#{key}" }
  end

  def set url, data
    key = url.gsub(@keyfilter, '')
    file = Oj.load_file(@cache_file_name)
    file[key] = data
    Oj.to_file(@cache_file_name, file, indent: 2)

    return true
  end

  def needs_update? url
    data = self.get url

    return true if data.nil?

    p data[:modified]
    return true if data[:modified].nil?

    # ~10 days
    p (Time.now - data[:modified])
    return (Time.now - data[:modified]) > 860000
  end
end
