##
# Setup global project settings for your apps. These settings are inherited by every subapp. You can
# override these settings in the subapps as needed.
#
Padrino.configure_apps do
  set :session_secret, 'a1c3ac57d4d692ee6e34bb11b49e60a4282e89f8df7722f7'
  set :protection, true
  set :protect_from_csrf, true
end

# Mounts the core application for this project
Padrino.mount('Inspiration::App', app_file: Padrino.root('app/app.rb')).to('/')
