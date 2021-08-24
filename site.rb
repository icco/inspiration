# frozen_string_literal: true

RACK_ENV = ENV["RACK_ENV"] ||= "development" unless defined?(RACK_ENV)

require "rubygems" unless defined?(Gem)
require "bundler/setup"
Bundler.require(:default, RACK_ENV)

require "json"
require "open-uri"
require "rss"
require "set"
require "logger"

require "./lib/logging"
require "./lib/scss_init"
require "./lib/image_db"

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

  DRIBBBLE_TOKEN = "13177c079f04b1dbd41c2c0399079b8d19cfd58156530c317d526dfc9e0a8479"

  FlickRaw.api_key = "5c282af934cd475695e1f727dd0404a9"
  FlickRaw.shared_secret = "49b3b77e99947328"
  FlickRaw.secure = true

  TWITTER_CONFIG = {
    consumer_key: "GQx89ku8NLacf02n2GzjgGvLa",
    consumer_secret: "6miWrWUFRNrTWsZ4Honnp1oAXDa1T2NtA6l1c4cCGD9Hy7GlWD",
    access_token: "3576561-R2m1fM1r0ogs5UPUeCzWJBc0cKfQatWfLIlouemrzv",
    access_token_secret: "lvWZMoeN9YN0OeTvwhx6M4w4wCaYEYZbYwkSuvG3sf5ij",
  }.freeze

  before do
    headers "NEL" => '{"report_to":"default","max_age":2592000}'
    headers "Report-To" => '{"group":"default","max_age":10886400,"endpoints":[{"url":"https://reportd.natwelch.com/report/inspiration"}]}'
  end

  get "/about" do
    erb :about
  end

  get "/" do
    erb :index
  end

  get "/data/:page/file.json" do
    @idb = ImageDB.new
    json @idb.page params[:page]
  end

  get "/stats.json" do
    @idb = ImageDB.new
    cnt = @idb.count
    stats = {
      per_page: PER_PAGE,
      images: cnt,
      pages: cnt / PER_PAGE,
    }
    json stats
  end
end
