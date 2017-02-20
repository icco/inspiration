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

  LINK_FILE = "links.txt".freeze
  CACHE_FILE = "cache.json".freeze
  PER_PAGE = 100
  OJ_OPTIONS = {
    mode: :compat,
    indent: 2,
    escape_mode: :json,
    class_cache: true,
    nan: :word,
    time_format: :ruby,
    use_to_json: true,
  }.freeze
  Oj.default_options = OJ_OPTIONS

  DRIBBBLE_TOKEN = "13177c079f04b1dbd41c2c0399079b8d19cfd58156530c317d526dfc9e0a8479".freeze

  FlickRaw.api_key = "5c282af934cd475695e1f727dd0404a9"
  FlickRaw.shared_secret = "49b3b77e99947328"
  FlickRaw.secure = true

  Instagram.configure do |config|
    config.client_id = "1503e0bccdd9424bb9d9590ba181bbbb"
    config.client_secret = "2c86ea5babf74038b592331d75e5ad7b"
  end
  INSTAGRAM_TOKEN = "2025166174.1503e0b.f6a0ee96f41f4f629a66d2e76f1127ac".freeze

  TWITTER_CONFIG = {
    consumer_key: "GQx89ku8NLacf02n2GzjgGvLa",
    consumer_secret: "6miWrWUFRNrTWsZ4Honnp1oAXDa1T2NtA6l1c4cCGD9Hy7GlWD",
    access_token: "3576561-R2m1fM1r0ogs5UPUeCzWJBc0cKfQatWfLIlouemrzv",
    access_token_secret: "lvWZMoeN9YN0OeTvwhx6M4w4wCaYEYZbYwkSuvG3sf5ij",
  }.freeze

  get "/about" do
    erb :about
  end

  get "/" do
    @images = PER_PAGE
    @idb = ImageDB.new
    @library = @idb.images.count

    erb :index
  end
end
