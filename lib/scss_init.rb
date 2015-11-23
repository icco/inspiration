module ScssInitializer
  def self.registered(app)
    # Enables support for SCSS template reloading in rack applications.
    # See http://nex-3.com/posts/88-sass-supports-rack for more details.
    # Store SCSS files (by default) within 'app/stylesheets'
    require "sass/plugin/rack"
    Sass::Plugin.options[:syntax] = :scss
    Sass::Plugin.options[:template_location] = "css"
    Sass::Plugin.options[:css_location] = "public/css"
    Sass::Plugin.options[:style] = :compressed
    Sass::Plugin.options[:always_update] = RACK_ENV.eql? :development
    app.use Sass::Plugin::Rack
  end
end
