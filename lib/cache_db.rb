# A class wrapper around the cache.json file. The file is a hash of objects.
# The key is the original url, the object contains information to render the
# image.
class CacheDB
  include Logging

  def initialize
    @cache_file_name = Inspiration::CACHE_FILE

    # Default Oj options
    Oj.default_options = {
      mode: :compat,
      indent: 2
    }
    @keyfilter = %r{[\/:\.\\\-@]}

    if File.extname(@cache_file_name).eql? ".json"
      @mode = "json"
      unless File.exist? @cache_file_name
        File.open(@cache_file_name, "w+") { |file| file.write("{}") }
      end
    elsif File.extname(@cache_file_name).eql? ".db"
      @mode = "sqlite"

      ActiveRecord::Base.establish_connection(
        adapter: "sqlite3",
        database: @cache_file_name
      )

      unless ActiveRecord::Base.connection.table_exists?(:caches)
        ActiveRecord::Migration.class_eval do
          create_table :caches do |t|
            t.string :key
            t.string :url
            t.string :image
            t.datetime :modified
            t.string :title
            t.integer :width
            t.integer :height
          end
        end
      end
    else
      fail "Invalid Cache Type!"
    end
  end

  def sqlite?
    @mode == "sqlite"
  end

  def json?
    @mode == "json"
  end

  def sample(count)
    if json?
      file = Oj.load_file(@cache_file_name)
      return file.values.sample(count).delete_if { |d| d.nil? || d["image"].nil? }
    elsif sqlite?
      query = Cache.where.not(image: nil).order("RANDOM()").limit(count)
      return query.map do |c|
        CacheSerializer.new(c)
      end
    end
  end

  def cache(url)
    return true unless needs_update? url

    hash = { url: url, modified: Time.now.utc }

    dribbble_re = %r{https://dribbble\.com/shots/}
    deviant_re = /deviantart\.com/
    flickr_re = /www\.flickr\.com/
    insta_re = %r{https://www.instagram\.com/p/}
    verygoods_re = /verygoods\.co/
    twitter_re = %r{https://twitter.com/}

    begin
      case url
      when dribbble_re
        id = url.gsub(dribbble_re, "").split("-").first
        data = Dribbble::Shot.find(Inspiration::DRIBBBLE_TOKEN, id)

        title = "\"#{data.title}\" by #{data.user['username']}"
        if !data.images["hidpi"].nil?
          image_link = data.images["hidpi"]
        else
          image_link = data.images["normal"]
        end

        attrs = {
          title: title,
          image: image_link,
          size: {
            width: data.width,
            height: data.height
          }
        }
        hash.merge! attrs
      when deviant_re
        oembed_url = "https://backend.deviantart.com/oembed?url=#{URI.escape(url, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))}&format=json"
        resp = Faraday.get oembed_url
        if resp.status == 200
          data = JSON.parse(resp.body)
        else
          logging.error "Code #{resp.status}: Hitting #{oembed_url} for #{url}"
          return
        end

        title = "\"#{data['title']}\" by #{data['author_name']}"
        attrs = { title: title, image: data["thumbnail_url"], size: { width: data["width"], height: data["height"] } }
        hash.merge! attrs
      when flickr_re
        oembed_url = "https://www.flickr.com/services/oembed?url=#{URI.escape(url, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))}&format=json&&maxwidth=400"
        resp = Faraday.get oembed_url
        if resp.status == 200
          data = JSON.parse(resp.body)
        else
          logging.error "Code #{resp.status}: Hitting #{oembed_url} for #{url}"
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
        title = "\"#{data['title']}\" by #{data['author_name']}"
        attrs = { title: title, image: image_url, size: { width: data["width"], height: data["height"] } }
        hash.merge! attrs
      when insta_re
        # OEMBED for INSTAGRAM
        oembed_url = "https://api.instagram.com/oembed/?url=#{URI.escape(url, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))}"
        resp = Faraday.get oembed_url
        if resp.status == 200
          data = JSON.parse(resp.body)
        else
          logging.error "Code #{resp.status}: Hitting #{oembed_url} for #{url}"
          return
        end

        title = "\"#{data['title']}\" by #{data['author_name']}"
        attrs = { title: title, image: data["thumbnail_url"], size: { width: data["thumbnail_width"], height: data["thumbnail_height"] } }
        hash.merge! attrs
      when verygoods_re
        # VeryGoods does not support OEmbed as of 2015-08-10
        oembed_url = "https://verygoods.co/site-api-0.1"
        oembed_url += URI(url).path.gsub(/product/, "products")
        resp = Faraday.get oembed_url
        if resp.status == 200
          data = JSON.parse(resp.body)
        else
          logging.error "Code #{resp.status}: Hitting #{oembed_url} for #{url}"
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

    unless hash[:title].empty? or hash[:image].empty?
      set url, hash
    end
  end

  def get(url)
    key = url.gsub(@keyfilter, "")

    if json?
      data = Oj::Doc.open_file(@cache_file_name) { |doc| doc.fetch "/#{key}" }

      if data.eql? []
        return nil
      else
        return data
      end
    elsif sqlite?
      data = Cache.where(key: key).first
      if data
        # So our data looks the same no matter what
        return Oj.compat_load(data.to_json)
      else
        return nil
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
      Oj.to_file(@cache_file_name, file)
    elsif sqlite?
      entry = Cache.find_or_create_by(key: key)
      entry.title = data[:title]
      entry.url = data[:url]
      entry.image = data[:image]
      entry.modified = data[:modified]
      entry.width = data[:size][:width] if data[:size]
      entry.height = data[:size][:height] if data[:size]
      entry.save
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
    elsif sqlite?
      Cache.delete(Cache.where(key: key))
    else
      return false
    end

    true
  end

  def all
    if json?
      return Oj.load_file(@cache_file_name)
    elsif sqlite?
      return Cache.all
    else
      return nil
    end
  end

  def needs_update?(url)
    data = get url

    return true if data.nil?

    return true if data["modified"].nil?

    # For Flickr wrong size stuff
    return true if data["image"].nil? || data["image"].match(/_q/)

    # ~10 days * a random float
    time = Time.parse(data["modified"])
    (Time.now.utc - time) > (860_000 * rand)
  end

  def clean(images)
    valid_keys = images.map { |i| i.gsub(@keyfilter, "") }.to_set
    if json?
      current_keys = all.keys.to_set
    elsif sqlite?
      current_keys = Set.new(Cache.uniq.pluck(:key))
    end
    to_delete = current_keys - valid_keys

    to_delete.each do |k|
      delete k
    end

    if sqlite?
      sql = "VACUUM FULL"
      ActiveRecord::Base.connection.execute(sql)
    end

    to_delete.count
  end

  def load_sql_to_json(sqlite_filename)
    ActiveRecord::Base.establish_connection(
      adapter: "sqlite3",
      database: sqlite_filename
    )

    Oj.to_file(@cache_file_name, Cache.all_as_hash)
  end
end

class CacheSerializer < ActiveModel::Serializer
  attributes :url, :title, :size, :image, :modified
  root false
end

class Cache < ActiveRecord::Base
  def size
    {
      height: height,
      width: width
    }
  end

  def self.all_as_hash
    hash = {}
    Cache.all.order(key: :asc).each do |c|
      hash[c.key] = CacheSerializer.new(c)
    end

    hash
  end
end
