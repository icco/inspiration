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
    set :logging, true            # Logging in STDOUT for development and file for production (default only for development)

    # Assets
    set :css_asset_folder, 'css'
    set :js_asset_folder, 'js'

    set :protection, true
    set :protect_from_csrf, true
    set :allow_disabled_csrf, true
  end

  LINK_FILE = Padrino.root("links.txt")
  CACHE_FILE = Padrino.root("cache.db")
  PER_PAGE = 400

  FlickRaw.api_key = "5c282af934cd475695e1f727dd0404a9"
  FlickRaw.shared_secret = "49b3b77e99947328"
  FlickRaw.secure = true
end
