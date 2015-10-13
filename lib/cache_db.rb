# A class wrapper around the cache.json file. The file is a hash of objects.
# The key is the original url, the object contains information to render the
# image.
class CacheDB
  def initialize
    @cache_file_name = Inspiration::CACHE_FILE

    # Default Oj options
    Oj.default_options = {
      mode: :compat,
      indent: 2,
    }
    @keyfilter = /[\/:\.\\\-@]/

    if File.extname(@cache_file_name).eql? ".json"
      @mode = "json"
      if !File.exists? @cache_file_name
        File.open(@cache_file_name, "w+") { |file| file.write("{}") }
      end
    elsif File.extname(@cache_file_name).eql? ".db"
      @mode = "sqlite"

      ActiveRecord::Base.establish_connection(
        :adapter => "sqlite3",
        :database => @cache_file_name
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
      raise "Invalid Cache Type!"
    end
  end

  def sqlite?
    return @mode == "sqlite"
  end

  def json?
    return @mode == "json"
  end

  def sample count
    if json?
      file = Oj.load_file(@cache_file_name)
      return file.values.sample(count).delete_if {|d| d.nil? or d["image"].nil? }
    elsif sqlite?
      return Cache.where.not(image: nil).order('RANDOM()').limit(count).map {|c| CacheSerializer.new(c) }
    end
  end

  def cache url
    if !needs_update? url
      return true
    end

    hash = {url: url, modified: Time.now}

    dribbble_re = %r{https://dribbble\.com/shots/}
    deviant_re = %r{deviantart\.com}
    flickr_re = %r{www\.flickr\.com}
    verygoods_re = %r{verygoods\.co}

    begin
      case url
      when dribbble_re
        # Dribbble does not like us, go slow
        sleep rand

        id = url.gsub(dribbble_re, "").split('-').first
        data = ImageDB.dribbble_client.get_shot(id)

        title = "\"#{data.title}\" by #{data.user["username"]}"
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
          logger.error "Code #{resp.status}: Hitting #{oembed_url} for #{url}"
          return
        end

        title = "\"#{data["title"]}\" by #{data["author_name"]}"
        attrs = {title: title, image: data["thumbnail_url"], size: {width: data["width"], height: data["height"]}}
        hash.merge! attrs
      when flickr_re
        oembed_url = "https://www.flickr.com/services/oembed?url=#{URI.escape(url, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))}&format=json&&maxwidth=400"
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

        if !data["url"]
          logger.error "No Tumbnail for #{url} at #{oembed_url}"
          return
        end

        image_url = data["url"]
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
    rescue StandardError => e
      logger.error "Failed #{oembed_url} for #{url}: #{e.inspect}"
    end

    return set url, hash
  end

  def get url
    key = url.gsub(@keyfilter, '')

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

  def set url, data
    key = url.gsub(@keyfilter, '')

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

    return true
  end

  def delete key
    if json?
      file = all
      file.delete key
      Oj.to_file(@cache_file_name, file)
    elsif sqlite?
      Cache.delete(Cache.where(key: key))
    else
      return false
    end

    return true
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

  def needs_update? url
    data = self.get url

    return true if data.nil?

    return true if data["modified"].nil?

    # For Flickr wrong size stuff
    return true if data["image"].nil? or data["image"].match /_q/

    # ~10 days * a random float
    time = Time.parse(data["modified"])
    return (Time.now - time) > (860000 * rand)
  end

  def clean images
    valid_keys = images.map {|i| i.gsub(@keyfilter, '') }.to_set
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

    return to_delete.count
  end

  def load_sql_to_json sqlite_filename
    ActiveRecord::Base.establish_connection(
      :adapter => "sqlite3",
      :database => sqlite_filename
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
    return {
      height: height,
      width: width,
    }
  end

  def self.all_as_hash
    hash = {}
    Cache.all.order(key: :asc).each do |c|
      hash[c.key] = CacheSerializer.new(c)
    end

    return hash
  end
end
