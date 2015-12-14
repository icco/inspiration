RACK_ENV ||= ENV["RACK_ENV"] ||= "development" unless defined?(RACK_ENV)

require "rubygems" unless defined?(Gem)
require "bundler/setup"
Bundler.require(:default, RACK_ENV)

require "json"
require "open-uri"
require "rss"
require "set"
require "logger"

require "./lib/logging.rb"
require "./lib/scss_init.rb"

require "./lib/cache_db.rb"
require "./lib/image_db.rb"

class Inspiration < Sinatra::Base
  register ScssInitializer
  use Rack::Deflater

  layout :main

  configure do
    enable :caching
    set :logging, true
    set :protection, true
    set :protect_from_csrf, true
    set :allow_disabled_csrf, true
  end

  LINK_FILE = "links.txt"
  CACHE_FILE = "cache.json"
  PER_PAGE = 400

  DRIBBBLE_TOKEN = "13177c079f04b1dbd41c2c0399079b8d19cfd58156530c317d526dfc9e0a8479"

  FlickRaw.api_key = "5c282af934cd475695e1f727dd0404a9"
  FlickRaw.shared_secret = "49b3b77e99947328"
  FlickRaw.secure = true

  Instagram.configure do |config|
    config.client_id = "696296edc81f417ea3418708c35485dd"
    config.client_secret = "76e99607d14f48dda453fb9c6109d55b"
  end
  INSTAGRAM_TOKEN = "2025166174.696296e.b8d7376606d04d38a745aea46d4284f5"

  COUNT = 400

  get "/about" do
    erb :about
  end

  get "/" do
    @images = COUNT
    @idb = ImageDB.new
    @library = @idb.images.count

    erb :index
  end

  get "/cache.json" do
    @count = COUNT
    @count = params["count"].to_i if params["count"]

    @idb = ImageDB.new
    @cdb = CacheDB.new
    @images = @idb.sample(@count).map { |u| @cdb.get u }

    content_type :json
    @images.to_json
  end

  get "/sample.json" do
    @count = COUNT
    @count = params["count"].to_i if params["count"]

    @cdb = CacheDB.new
    @images = @cdb.sample(@count)

    content_type :json
    @images.to_json
  end

  get "/all_images.json" do
    @idb = ImageDB.new
    @cdb = CacheDB.new

    content_type :json
    @cdb.all.map {|k, v| v["image"] }.to_json
  end

  get "/all.json" do
    @idb = ImageDB.new
    @cdb = CacheDB.new

    content_type :json
    @idb.images.to_json
  end
end
