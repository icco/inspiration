Inspiration::App.controllers  do
  layout :main

  get :about, :cache => true do
    expires_in 3600 # 1 hr

    idb = ImageDb.new
    @images = idb.images.sample(150)
    @text = partial :about

    @stats = Hash.new(0)

    # @images.each do |url|
    #   matches = url.match(/.+:\/\/(.+)\.deviantart/)
    #   name = matches[1]
    #   @stats[name] += 1
    # end
    @stats = @stats.to_a.sort {|a,b| b[1] <=> a[1] }

    render :about
  end

  get :index do
    idb = ImageDb.new
    @images = idb.images.sample(150)

    render :index
  end

  get :all do
    require 'json'

    idb = ImageDb.new
    @images = idb.images

    content_type :json
    @images.to_json
  end
end
