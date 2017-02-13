require "bundler/setup"
require "./site"

task default: :static

BUILD_DIR = File.join(Dir.pwd, "build")

desc "Build a static version of the site."
task :static do
  require "fileutils"

  # Layout
  layout = Tilt.new('views/layout.erb')

  # About
  about_dir = File.join(BUILD_DIR, "about")
  FileUtils.mkdir_p(about_dir)
  about = Tilt.new('views/about.erb')
  File.open(File.join(about_dir, "index.html"), 'w') { |file| file.write(layout.render { about.render }) }

  # Root
  index = Tilt.new('views/index.erb')
  File.open(File.join(BUILD_DIR, "index.html"), 'w') { |file| file.write(layout.render { index.render }) }

  # Other Files
  FileUtils.cp_r 'public/.', BUILD_DIR

  # JSON Data
  data_dir = File.join(BUILD_DIR, "data")
  FileUtils.mkdir_p(data_dir)
  cdb = CacheDB.new
  idb = ImageDB.new
  all = idb.images.shuffle
  page = 0
  i = 0
  while i < all.length
    page += 1
    b = page * Inspiration::PER_PAGE
    data = all[i...b].map { |img| cdb.get(img) }.compact
    Oj.to_file(File.join(data_dir, "#{page}.json"), data)
    i = b
  end

  data = {
    per_page: Inspiration::PER_PAGE,
    pages: page,
    images: all.length,
  }
  Oj.to_file(File.join(BUILD_DIR, "stats.json"), data)
end

desc "Run a local server."
task :local do
  Kernel.exec("shotgun -s thin -p 9393")
end

desc "Update links."
task :update_some_links do
  idb = ImageDB.new
  idb.update
end

desc "Get update all links."
task :update_links do
  idb = ImageDB.new
  idb.full_update
end

desc "Build a cache of the image db."
task :build_cache do
  cdb = CacheDB.new
  idb = ImageDB.new

  idb.images.to_a.shuffle.each do |i|
    cdb.cache i
  end
end

desc "Try to update 10 images in the cache."
task :build_cache_random do
  cdb = CacheDB.new
  idb = ImageDB.new

  idb.images.to_a.sample(10).each do |i|
    cdb.cache i
  end
end

desc "Remove unused images in cache."
task :clean do
  FileUtils.rm_rf(BUILD_DIR)

  cdb = CacheDB.new
  idb = ImageDB.new
  cdb.clean idb.images
end

desc "Download all images into a folder."
task :download do
  require "open-uri"
  require "uri"
  require "digest/sha1"
  require "mime/types"

  cdb = CacheDB.new
  cdb.all.map { |_k, v| v["image"] }.delete_if { |i| i.nil? || i.empty? }.sort.each do |i|
    url = URI(i)
    filename = Digest::SHA1.hexdigest(i)
    ext = File.extname(i)
    open(url) do |u|
      ext = if ext.empty?
              MIME::Types[u.content_type].first.extensions.first
            else
              ext[1..-1]
            end
      path = "/Users/nat/Dropbox/Photos/Inspiration/#{filename}.#{ext}"

      next if ext == "bin"

      open(path, "wb") do |file|
        begin
          puts "Downloading #{i}"
          file << u.read
        rescue OpenURI::HTTPError => e
          puts "Open URI error - #{e}"
        end
      end
    end
  end
end
