require "sinatra"
require "instagram"
require "pp"

enable :sessions

CALLBACK_URL = "http://localhost:9393/oauth/callback".freeze

Instagram.configure do |config|
  config.client_id = "1503e0bccdd9424bb9d9590ba181bbbb"
  config.client_secret = "2c86ea5babf74038b592331d75e5ad7b"
end

get "/" do
  '<a href="/oauth/connect">Connect with Instagram</a>'
end

get "/oauth/connect" do
  redirect Instagram.authorize_url(redirect_uri: CALLBACK_URL, scope: "public_content")
end

get "/oauth/callback" do
  response = Instagram.get_access_token(params[:code], redirect_uri: CALLBACK_URL)
  session[:access_token] = response.access_token
  redirect "/nav"
end

get "/nav" do
  html =
    """
      <h1>Ruby Instagram Gem Sample Application</h1>
      <ol>
        <li><a href='/user_recent_media'>User Recent Media</a> Calls user_recent_media - Get a list of a user's most recent media</li>
        <li><a href='/user_media_feed'>User Media Feed</a> Calls user_media_feed - Get the currently authenticated user's media feed uses pagination</li>
        <li><a href='/user_likes'>User likes</a></li>
        <li><a href='/location_recent_media'>Location Recent Media</a> Calls location_recent_media - Get a list of recent media at a given location, in this case, the Instagram office</li>
        <li><a href='/media_search'>Media Search</a> Calls media_search - Get a list of media close to a given latitude and longitude</li>
        <li><a href='/media_popular'>Popular Media</a> Calls media_popular - Get a list of the overall most popular media items</li>
        <li><a href='/user_search'>User Search</a> Calls user_search - Search for users on instagram, by name or username</li>
        <li><a href='/location_search'>Location Search</a> Calls location_search - Search for a location by lat/lng</li>
        <li><a href='/location_search_4square'>Location Search - 4Square</a> Calls location_search - Search for a location by Fousquare ID (v2)</li>
        <li><a href='/limits'>View Rate Limit and Remaining API calls</a>View remaining and ratelimit info.</li>
      </ol>
    """
  html
end

get "/user_recent_media" do
  client = Instagram.client(access_token: session[:access_token])
  user = client.user
  html = "<h1>#{user.username}'s recent media</h1>"
  client.user_recent_media.each do |media_item|
    html << "<div style='float:left;'><img src='#{media_item.images.thumbnail.url}'><br/> <a href='/media_like/#{media_item.id}'>Like</a>  <a href='/media_unlike/#{media_item.id}'>Un-Like</a>  <br/>LikesCount=#{media_item.likes[:count]}</div>"
  end
  html
end

get "/media_like/:id" do
  client = Instagram.client(access_token: session[:access_token])
  client.like_media(params[:id].to_s)
  redirect "/user_recent_media"
end

get "/media_unlike/:id" do
  client = Instagram.client(access_token: session[:access_token])
  client.unlike_media(params[:id].to_s)
  redirect "/user_recent_media"
end

get "/user_likes" do
  client = Instagram.client(access_token: session[:access_token])
  pp client, session[:access_token]
  user = client.user
  html = "<h1>#{user.username}'s likes feed</h1>"
  client.user_liked_media.each do |i|
    html << "<div style='float:left;'><a href='#{i.link}'><img title='#{i.link}' src='#{i.images.standard_resolution.url}'></a></div>"
  end

  html
end

get "/user_media_feed" do
  client = Instagram.client(access_token: session[:access_token])
  user = client.user
  html = "<h1>#{user.username}'s media feed</h1>"

  page_1 = client.user_media_feed(777)
  page_2_max_id = page_1.pagination.next_max_id
  page_2 = client.user_recent_media(777, max_id: page_2_max_id) unless page_2_max_id.nil?
  html << "<h2>Page 1</h2><br/>"
  page_1.each do |media_item|
    html << "<img src='#{media_item.images.thumbnail.url}'>"
  end
  html << "<h2>Page 2</h2><br/>"
  page_2.each do |media_item|
    html << "<img src='#{media_item.images.thumbnail.url}'>"
  end
  html
end

get "/location_recent_media" do
  client = Instagram.client(access_token: session[:access_token])
  html = "<h1>Media from the Instagram Office</h1>"
  client.location_recent_media(514_276).each do |media_item|
    html << "<img src='#{media_item.images.thumbnail.url}'>"
  end
  html
end

get "/media_search" do
  client = Instagram.client(access_token: session[:access_token])
  html = "<h1>Get a list of media close to a given latitude and longitude</h1>"
  client.media_search("37.7808851", "-122.3948632").each do |media_item|
    html << "<img src='#{media_item.images.thumbnail.url}'>"
  end
  html
end

get "/media_popular" do
  client = Instagram.client(access_token: session[:access_token])
  html = "<h1>Get a list of the overall most popular media items</h1>"
  client.media_popular.each do |media_item|
    html << "<img src='#{media_item.images.thumbnail.url}'>"
  end
  html
end

get "/user_search" do
  client = Instagram.client(access_token: session[:access_token])
  html = "<h1>Search for users on instagram, by name or usernames</h1>"
  client.user_search("instagram").each do |user|
    html << "<li> <img src='#{user.profile_picture}'> #{user.username} #{user.full_name}</li>"
  end
  html
end

get "/location_search" do
  client = Instagram.client(access_token: session[:access_token])
  html = "<h1>Search for a location by lat/lng with a radius of 5000m</h1>"
  client.location_search("48.858844", "2.294351", "5000").each do |location|
    html << "<li> #{location.name} <a href='https://www.google.com/maps/preview/@#{location.latitude},#{location.longitude},19z'>Map</a></li>"
  end
  html
end

get "/location_search_4square" do
  client = Instagram.client(access_token: session[:access_token])
  html = "<h1>Search for a location by Fousquare ID (v2)</h1>"
  client.location_search("3fd66200f964a520c5f11ee3").each do |location|
    html << "<li> #{location.name} <a href='https://www.google.com/maps/preview/@#{location.latitude},#{location.longitude},19z'>Map</a></li>"
  end
  html
end

get "/limits" do
  client = Instagram.client(access_token: session[:access_token])
  html = "<h1/>View API Rate Limit and calls remaining</h1>"
  response = client.utils_raw_response
  html << "Rate Limit = #{response.headers[:x_ratelimit_limit]}.  <br/>Calls Remaining = #{response.headers[:x_ratelimit_remaining]}"

  html
end
