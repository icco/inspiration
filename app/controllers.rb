Inspiration::App.controllers  do
  layout :main

  COUNT = 400

  get :about do
    idb = ImageDB.new
    @images = idb.images
    @text = partial :about

    render :about
  end

  get :index do
    @images = COUNT
    @idb = ImageDB.new
    @library = @idb.images.count

    render :index
  end

  get "/cache.json" do
    @count = params["count"].to_i || COUNT

    @idb = ImageDB.new
    @cdb = CacheDB.new
    @images = @idb.sample(@count).map {|u| @cdb.get u }

    content_type :json
    @images.to_json
  end
end
