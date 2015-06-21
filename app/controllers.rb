Inspiration::App.controllers  do
  layout :main

  get :about do
    idb = ImageDb.new
    @images = idb.images
    @text = partial :about

    @stats = Hash.new(0)
    @stats = @stats.to_a.sort {|a,b| b[1] <=> a[1] }

    render :about
  end

  get :index do
    @idb = ImageDb.new
    @images = @idb.images.to_a.sample count
    @cached = []
    @count = { i: @idb.images.count, c: 0 }

    render :index
  end

  get "/all.json" do
    idb = ImageDb.new
    @images = idb.images

    content_type :json
    @images.to_json
  end

  get :all do
    @idb = ImageDb.new
    @images = @idb.images.shuffle
    @cached = []
    @count = { i: @idb.images.count, c: 0 }

    render :index
  end
end
