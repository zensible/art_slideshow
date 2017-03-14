require 'digest'

class HomeController < ApplicationController
  before_filter :get_id

  def get_id
    md5 = Digest::MD5.new
    if cookies["browser-id"].nil?
      cookies["browser-id"] = rand(100000000).to_s
    end
    @id = cookies["browser-id"]
  end

  # Renders a blank page with the application.html.haml layout. Its ng-app and ng-controller attributes bootstrap the application and call template, below
  def index
    sql = ""

    sql = "SELECT DISTINCT(department) FROM image_entries ORDER BY department"
    records_array = ActiveRecord::Base.connection.execute(sql)
    @categories = [ 'ALL' ]
    records_array.each do |rec|
      @categories.push(rec[0])
    end
  end

  # Since the app is a one-pager, this only renders views/templates/home.html.haml
  def template
    template_name = params[:template_name]

    render "templates/#{template_name}", locals: {  }, :layout => nil
  end

  def random_image
    sta = Time.now.to_i

    tries = 10

    begin

      Rails.logger.info Time.now.to_i.to_s

      cat = ""
      if params[:category] && params[:category] != 'ALL'
        cat = " AND department = '#{params[:category]}'"
      end

      era = ""
      if params[:era] && params[:era] != 'ALL'
        arr = params[:era].split("_")
        begi = arr[0]
        en = arr[1]
        era = " AND object_end_date >= #{begi} AND object_end_date <= #{en} "
      end

      sql = "SELECT * FROM image_entries WHERE true = true #{cat} #{era} ORDER BY rand() LIMIT 1"
      entry = nil
      ImageEntry.uncached do
        entry = ImageEntry.find_by_sql(sql).first
      end
      render :json => {} and return if entry.nil?

      link = entry.link_resource

      Rails.logger.info (Time.now.to_i - sta).to_s

      puts "== Met link: #{link}"
      html = `curl '#{link}'`
      arr = html.match(/<a href="\{\{selectedOrDefaultDownload\(&#039;(.+)&#039;\)}}"/)

      arr = html.match(/http:\/\/images\.metmuseum\.org\/CRDImages\/(\w+)\/original\/(.+)\.(jpg|JPG|jpeg|JPEG|Jpg|Jpeg)/)

      Rails.logger.info (Time.now.to_i - sta).to_s
      if arr
        abbrev = arr[1]
        fn = arr[2]
        url = "http://images.metmuseum.org/CRDImages/#{abbrev}/original/#{fn}.jpg"
        puts "== Url: #{url}"

        fn = "#{entry.id}-#{@id}.jpg"
        path = "./public/downloaded/#{fn}"
        puts "== path: #{path}"

        cmd = "curl -o #{path} #{url}"
        `#{cmd}`
        FastImage.resize(path, 2000, 0, :outfile => path)

        # Clean up images we've already seen
        Dir.glob("./public/downloaded/*.jpg").each do |itm|
          if !itm.match(/\/#{entry.id}-#{@id}\.jpg/) && itm.match(/-#{@id}/)
            File.delete(itm)
          end
        end

        Rails.logger.info (Time.now.to_i - sta).to_s
        render :json => entry.attributes and return
      else
        Rails.logger.error "Couldn't extract the URL!"
        raise "Couldn't extract the URL!"
      end
    rescue Exception => ex
      tries -= 1
      if tries > 0
        Rails.logger.error ex.message
        retry
      else
        Rails.logger.error "Fatal error!!!!! #{ex.message}"
        Rails.logger.error ex.message
        render :json => { success: false }, status: 500 and return
      end
    end

  end

end
