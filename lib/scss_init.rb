# frozen_string_literal: true

module ScssInitializer
  def self.registered(app)
    app.use Rack::SassC, 
      syntax: :scss,
      css_location: "public/css",
      scss_location: "css",
      create_map_file: true,
  end
end
