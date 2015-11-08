Inspiration::App.controllers do
  layout :main

  COUNT = 400

  get :about do
    render :about
  end

  get :index do
    @images = COUNT
    @idb = ImageDB.new
    @library = @idb.images.count

    render :index
  end

  get "/cache.json" do
    @count = COUNT
    @count = params["count"].to_i if params["count"]

    @idb = ImageDB.new
    @cdb = CacheDB.new
    @images = @idb.sample(@count).map { |u| @cdb.get u }

    content_type :json
    @images.to_json
  end

  get "/sample.json" do
    @count = COUNT
    @count = params["count"].to_i if params["count"]

    @cdb = CacheDB.new
    @images = @cdb.sample(@count)

    content_type :json
    @images.to_json
  end

  get "/all.json" do
    @idb = ImageDB.new
    @cdb = CacheDB.new

    content_type :json
    @idb.images.to_json
  end
end
