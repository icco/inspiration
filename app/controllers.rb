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
    @count = COUNT
    @count = params["count"].to_i if params["count"]

    @idb = ImageDB.new
    @cdb = CacheDB.new
    @images = @idb.sample(@count).map {|u| @cdb.get u }.delete_if {|d| d.nil? or d["image"].nil? }

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
