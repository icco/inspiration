module Inspiration
  class App < Padrino::Application
    register ScssInitializer
    register Padrino::Rendering
    register Padrino::Mailer
    register Padrino::Helpers

    enable :sessions

    ##
    # Caching support
    register Padrino::Cache
    enable :caching

    ##
    # Application configuration options
    set :logging, true            # Logging in STDOUT for development and file for production (default only for development)

    set :protection, true
    set :protect_from_csrf, true
    set :allow_disabled_csrf, true
  end

  LINK_FILE = Padrino.root("links.txt")
  CACHE_FILE = Padrino.root("cache.json")
  PER_PAGE = 300

  FlickRaw.api_key = "5c282af934cd475695e1f727dd0404a9"
  FlickRaw.shared_secret = "49b3b77e99947328"
  FlickRaw.secure = true
end
