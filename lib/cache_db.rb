# A class wrapper around the cache.json file. The file is a hash of objects.
# The key is the original url, the object contains information to render the
# image.
class CacheDB

  def initialize
    @cache = JSON.parse(File.readlines(Inspiration::CACHE_FILE))
  end

  def cache url
    dribbble_re = %r{http://dribbble\.com/shots/}
    deviant_re = %r{deviantart\.com}
    flickr_re = %r{www\.flickr\.com}

    case url
    when dribbble_re
      oembed_url = "http://api.dribbble.com/shots/#{url.gsub(dribbble_re, "")}"
      p oembed_url

      # get oembed_url
      # title = '"' + images.title + '" by ' + images.player.name
      # if (images.image_400_url != undefined) {
      #   image_link = images.image_400_url
      # } else {
      #   image_link = images.image_teaser_url
      # }
    when deviant_re
      oembed_url = "http://backend.deviantart.com/oembed?url=#{URI.escape(url, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))}&format=jsonp"
      p oembed_url
    when flickr_re
      oembed_url = "http://www.flickr.com/services/oembed?url=#{URI.escape(url, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))}&format=json&&maxwidth=300"
      p oembed_url

      # title = '"' + images.title + '" by ' + images.author_name
      # image_url = images.thumbnail_url.replace(/\_s\./, "_n.")
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
