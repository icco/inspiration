# A class wrapper around the cache.json file. The file is a hash of objects.
# The key is the original url, the object contains information to render the
# image.
class CacheDB

  def initialize
    Oj.default_options = {
      mode: :compat,
      indent: 2,
    }
    @cache_file_name = Inspiration::CACHE_FILE
    @keyfilter = /[\/:\.]/
  end

  def sample count
    file = Oj.load_file(@cache_file_name)
    return file.values.sample(count)
  end

  def cache url
    if !needs_update? url
      return true
    end

    hash = {url: url, modified: Time.now}

    dribbble_re = %r{http://dribbble\.com/shots/}
    deviant_re = %r{deviantart\.com}
    flickr_re = %r{www\.flickr\.com}
    verygoods_re = %r{verygoods\.co}

    begin
      case url
      when dribbble_re
        # Dribbble does not like us, go slow
        sleep rand

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

        attrs = {title: title, image: image_link, size: {width: data["width"], height: data["height"]}}
        hash.merge! attrs
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
        attrs = {title: title, image: data["thumbnail_url"], size: {width: data["width"], height: data["height"]}}
        hash.merge! attrs
      when flickr_re
        oembed_url = "https://www.flickr.com/services/oembed?url=#{URI.escape(url, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))}&format=json&&maxwidth=300"
        resp = Faraday.get oembed_url
        if resp.status == 200
          data = JSON.parse(resp.body)
        else
          logger.error "Code #{resp.status}: Hitting #{oembed_url} for #{url}"
          return
        end

        # Licenses are blocking embeding I think.
        if data["type"] == "link"
          # TODO: embed by scraping "/sizes/m/"
          logger.info "Flickr won't let us embed this: #{url}."
          return
        end

        if !data["thumbnail_url"]
          logger.error "No Tumbnail for #{url} at #{oembed_url}"
          return
        end

        image_url = data["thumbnail_url"].gsub(/\_s\./, "_n.")
        title = "\"#{data["title"]}\" by #{data["author_name"]}"
        attrs = {title: title, image: image_url, size: {width: data["width"], height: data["height"]}}
        hash.merge! attrs
      when verygoods_re
        # VeryGoods does not support OEmbed as of 2015-08-10
        oembed_url = "https://verygoods.co/site-api-0.1"
        oembed_url += URI(url).path.gsub(/product/, "products")
        resp = Faraday.get oembed_url
        if resp.status == 200
          data = JSON.parse(resp.body)
        else
          logger.error "Code #{resp.status}: Hitting #{oembed_url} for #{url}"
          return
        end

        title = data["title"]
        image_url = data["medium_image_url"]
        size = {width: 400, height: nil} # TODO
        attrs = {title: title, image: image_url, size: size}
        hash.merge! attrs
      else
        logger.error "No idea what url this is: #{url}"
      end

      return set url, hash
    rescue Exception => e
      logger.error "Failed #{oembed_url} for #{url}: #{e.inspect}"
    end
  end

  def get url
    key = url.gsub(@keyfilter, '')
    return Oj::Doc.open_file(@cache_file_name) { |doc| doc.fetch "/#{key}" }
  end

  def set url, data
    key = url.gsub(@keyfilter, '')
    file = all
    file[key] = data
    Oj.to_file(@cache_file_name, file)

    return true
  end

  def delete key
    file = all
    file.delete key
    Oj.to_file(@cache_file_name, file)

    return true
  end

  def all
    return Oj.load_file(@cache_file_name)
  end

  def needs_update? url
    data = self.get url

    return true if data.nil?

    return true if data["modified"].nil?

    # ~10 days * a random float
    time = Time.parse(data["modified"])
    return (Time.now - time) > (860000 * rand)
  end

  def clean images
    valid_keys = images.map {|i| i.gsub(@keyfilter, '') }.to_set
    current_keys = all.keys.to_set
    to_delete = current_keys - valid_keys

    to_delete.each do |k|
      delete k
    end

    return to_delete.count
  end
end
