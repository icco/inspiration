
# Load our dependencies
require "rubygems" unless defined?(Gem)
require "bundler/setup"
Bundler.require(:default, RACK_ENV)

require "json"
require "open-uri"
require "rss"
require "set"

configure do
  set :session_secret, "a1c3ac57d4d692ee6e34bb11b49e60a4282e89f8df7722f7"
  set :protection, true
  set :protect_from_csrf, true
end

RACK_ENV ||= ENV["RACK_ENV"] ||= "development" unless defined?(RACK_ENV)
