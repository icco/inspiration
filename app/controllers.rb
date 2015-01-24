Inspiration::App.controllers  do
  layout :main

  get :about, :cache => true do
    expires_in 3600 # 1 hr

    idb = ImageDb.new
    @images = idb.images
    @text = partial :about

    @stats = Hash.new(0)
    @stats = @stats.to_a.sort {|a,b| b[1] <=> a[1] }

    render :about
  end

  get :index do
    @idb = ImageDb.new
    @images, @cached = @idb.sample(Inspiration::PER_PAGE)
    @count = { i: @idb.images.count, c: @idb.images.to_a.delete_if {|i| !@idb.cached? i }.count }

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
    @images, @cached = @idb.sample(@idb.images.count)
    @count = { i: @idb.images.count, c: @idb.images.to_a.delete_if {|i| !@idb.cached? i }.count }

    render :index
  end

  post :cache do
    idb = ImageDb.new
    ret = false

    if params[:favorite] and params[:image]
      ret = idb.cache(params[:favorite], params[:image])
    elsif params[:pairs]
      ret = []
      params[:pairs].each do |key, pair|
        src, img = pair
        ret.push idb.cache(src, img)
      end
    end

    status 400 if (not ret) or (ret and ret.include? false)
    content_type :json
    ret.to_json
  end
end
