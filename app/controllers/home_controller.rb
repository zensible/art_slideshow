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

    #begin

      Rails.logger.info Time.now.to_i.to_s

      key = "ids"

      cat = ""
      if params[:category] && params[:category] != 'ALL'
        key += "::" + params[:category]
        cat = " AND department = '#{params[:category]}'"
      end

      era = ""
      if params[:era] && params[:era] != 'ALL'
        key += "::" + params[:era]
        arr = params[:era].split("_")
        begi = arr[0]
        en = arr[1]
        era = " AND object_end_date >= #{begi} AND object_end_date <= #{en} "
      end

      ids = $redis.get(key)
      if ids.blank?
        ids = []
        sql = "SELECT id FROM image_entries WHERE host_me=1 #{cat} #{era} and full_description is not null"
        results = ActiveRecord::Base.connection.execute(sql)
        results.each do |row|
          ids.push(row[0])
        end
        $redis.set(key, JSON.dump(ids))
      else
        ids = JSON.load(ids)
      end

      id = ids.sample
      render :json => { success: false }, status: 200 and return if id.blank?

      sql = "SELECT * FROM image_entries WHERE id = #{id}"
      entry = nil
      ImageEntry.uncached do
        entry = ImageEntry.find_by_sql(sql).first
      end
      render :json => entry.attributes and return

    #rescue Exception => ex
    #  render :json => { success: false }, status: 500 and return
    #end

  end

end
