module Inspiration
  class App < Padrino::Application
    register ScssInitializer
    register Padrino::Rendering
    register Padrino::Mailer
    register Padrino::Helpers

    use Rack::Deflater

    enable :sessions

    ##
    # Caching support
    register Padrino::Cache
    enable :caching

    ##
    # Application configuration options
    # Logging in STDOUT for development and file for production (default only for development)
    set :logging, true

    # Assets
    set :css_asset_folder, "css"
    set :js_asset_folder, "js"

    set :protection, true
    set :protect_from_csrf, true
    set :allow_disabled_csrf, true
  end

  LINK_FILE = Padrino.root("links.txt")
  CACHE_FILE = Padrino.root("cache.json")
  PER_PAGE = 400

  DRIBBBLE_TOKEN = "13177c079f04b1dbd41c2c0399079b8d19cfd58156530c317d526dfc9e0a8479"

  FlickRaw.api_key = "5c282af934cd475695e1f727dd0404a9"
  FlickRaw.shared_secret = "49b3b77e99947328"
  FlickRaw.secure = true

  Instagram.configure do |config|
    config.client_id = "696296edc81f417ea3418708c35485dd"
    config.client_secret = "76e99607d14f48dda453fb9c6109d55b"
  end
end
