Inspiration::App.controllers  do
  layout :main

  get :about, :cache => true do
    expires_in 3600 # 1 hr

    idb = ImageDb.new
    @images = idb.images
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
    @idb = ImageDb.new
    @images = @idb.images.sample(Inspiration::PER_PAGE)

    render :index
  end

  get :all do
    idb = ImageDb.new
    @images = idb.images

    content_type :json
    @images.to_json
  end

  post :cache do
    idb = ImageDb.new
    ret = false
    if params[:favorite] and params[:image]
    ret = idb.cache(params[:favorite], params[:image])
    elsif params[:pairs]
      params[:pairs].each do |key, pair|
        src, img = pair
        ret = idb.cache(src, img)
      end
    end

    content_type :json
    ret.to_json
  end
end
