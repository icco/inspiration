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
    set :cache, Padrino::Cache::Store::Memory.new(50)

    ##
    # Application configuration options
    set :logging, true            # Logging in STDOUT for development and file for production (default only for development)
  end

  LINK_FILE = Padrino.root("links.txt")
end
