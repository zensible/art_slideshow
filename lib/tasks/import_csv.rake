require 'csv'
require 'digest/md5'

namespace :csv do

  # Step 1: populate database
  task :import => :environment do
    abort "Already imported"

    puts "= 01 - start"
    sql = "
TRUNCATE image_entries;
    "
    ActiveRecord::Base.connection.execute(sql)
    puts "= 02 - clear db"

    sql = "ALTER TABLE image_entries AUTO_INCREMENT = 1;"
    ActiveRecord::Base.connection.execute(sql)

    puts "= 03 - create indexes"

    num = 0

    fields = [
      :object_number,
      :is_highlight,
      :is_public_domain,
      :object_id,
      :department,
      :object_name,
      :title,
      :culture,
      :period,
      :dynasty,
      :reign,
      :portfolio,
      :artist_role,
      :artist_prefix,
      :artist_display_name,
      :artist_display_bio,
      :artist_suffix,
      :artist_alpha_sort,
      :artist_nationality,
      :artist_begin_date,
      :artist_end_date,
      :object_date,
      :object_begin_date,
      :object_end_date,
      :medium,
      :dimensions,
      :credit_line,
      :geography_type,
      :city,
      :state,
      :county,
      :country,
      :region,
      :subregion,
      :locale,
      :locus,
      :excavation,
      :river,
      :classification,
      :rights_and_reproduction,
      :link_resource,
      :metadata_date,
      :repository
    ]

    CSV.foreach('./lib/tasks/MetObjects.csv',
                :quote_char=>'"',
                :col_sep =>",", 
                :headers => true, 
                :force_quotes => true,
                :header_converters => :symbol ) do |row| 

      num += 1
      next if num == 1

      hsh = {}
      is_highlight = false
      is_public_domain = false
      is_object_we_want = false
      fields.each_with_index do |fld, i|
        val = row.field(i)
        if [ :is_highlight, :is_public_domain ].include?(fld)
          if val == 'True'
            hsh[fld] = 1
          else
            hsh[fld] = 0
          end
          if fld == :is_highlight
            is_highlight = hsh[fld]
          end
          if fld == :is_public_domain
            is_public_domain = hsh[fld]
          end
        else
          hsh[fld] = val ? val.slice(0, 255) : nil
        end
      end
      begin
        hsh[:object_name] ||= ""
        if is_public_domain == 1  && (!hsh[:title] || (hsh[:title] && !hsh[:title].match(/cigarette|Cigarette/)))  # There are about 15000 cigarette art prints that are ahhh kind of lame. It's better to filter them out, trust me.
          puts "create"
          ImageEntry.create(hsh)
        end
      rescue Exception => ex
        arr2 = ex.message.match(/Data too long for column '(.+)' at row/)
        if arr2
          puts arr2[1] + ',' + row.field(arr2[1].to_sym).length.to_s
        else
          raise ex
        end
      end
      #abort "done" if num == 10000
    end
    puts "DONE!"
  end

  # Step 2: populate url_jpeg and met_html
  task :get_url_html => :environment do
    sleep_time = 0.1
    offset = ENV['OFFSET'] || "0"
    while true
      sql = "SELECT * FROM image_entries WHERE met_html IS NULL AND id > #{offset} ORDER BY id LIMIT 100"
      puts sql
      entries = []
      ImageEntry.uncached do
        entries = ImageEntry.find_by_sql(sql)
      end
      if entries.count > 0
        entries.each do |entry|
          begin
            link = entry.link_resource

            puts "== Met link: #{link}"
            html = `curl '#{link}'`
            doc = Nokogiri::HTML html
            node = doc.css(".g-primary")
            entry.met_html = node.to_s
            #arr = html.match(/<a href="\{\{selectedOrDefaultDownload\(&#039;(.+)&#039;\)}}"/)

            arr = html.match(/http:\/\/images\.metmuseum\.org\/CRDImages\/(\w+)\/original\/(.+)\.(jpg|JPG|jpeg|JPEG|Jpg|Jpeg)/)

            if arr
              abbrev = arr[1]
              fn = arr[2]
              url = "http://images.metmuseum.org/CRDImages/#{abbrev}/original/#{fn}.jpg"
              entry.url_jpeg = url
              puts "== Url: #{url}"

              #fn = "#{entry.object_id}-full.jpg"
              #path = "./public/downloaded/archive/#{fn}"
              #puts "== path: #{path}"

              #cmd = "curl -o #{path} #{url}"
              #{}`#{cmd}`
              #FastImage.resize(path, 2000, 0, :outfile => "./public/downloaded/archive/#{entry.object_id}-resized.jpg")

              entry.downloaded = 3
              entry.save
            else
              Rails.logger.error "Couldn't extract the URL!"
              raise "Couldn't extract the URL!"
            end
          rescue Exception => ex
            puts ex.message
            entry.downloaded = -1
            entry.save
            sleep 10
          end
          puts "sleeping #{sleep_time}"
          sleep sleep_time
        end
        puts "sleeping #{30}"
        #sleep 30
      else # if
        raise "Done!"
      end
    end # while
  end # task

  # Step 3: download and process images
  task :download => :environment do
    sleep_time = 0.1
    while true
      sql = "SELECT * FROM image_entries WHERE url_jpeg IS NOT NULL AND md5 IS NULL ORDER BY id LIMIT 100"
      entries = []
      ImageEntry.uncached do
        entries = ImageEntry.find_by_sql(sql)
      end
      if entries.count > 0
        entries.each do |entry|
          url = entry.url_jpeg

          begin
            fn_in = "#{entry.object_id}-full.jpg"
            path_in = "./public/downloaded/archive/#{fn_in}"
            puts "== path: #{path_in}"
            if !File.exist? path_in
              cmd = "curl -o #{path_in} #{url}"
              `#{cmd}`
            end

            entry.md5 = Digest::MD5.hexdigest(File.read(path_in))
            entry.save

            # resize
            arr = FastImage.size(path_in)
            next if arr.nil?
            puts arr.inspect
            wid = arr[0]
            hei = arr[1]

            fn_out = entry.md5 + ".jpg"
            path_out = "./public/archive/#{fn_out}"

            if !File.exist? path_out
              puts "Out: #{path_out}"
              if wid > hei
                FastImage.resize(path_in, 1800, 0, :outfile => path_out)
              else
                FastImage.resize(path_in, 0, 1800, :outfile => path_out)
              end
            end
          rescue Exception => ex
            if ex.to_s == "Interrupt"
              abort "Done"
            end
            puts ex.inspect
            entry.md5 = nil
            entry.save
          end

        end
      else # if
        raise "Done!"
      end
    end # while
  end # task

  # Step 4: upload to s3
  task :upload_to_s3 => :environment do
    sleep_time = 0.1
    while true
      sql = "SELECT * FROM image_entries WHERE met_html IS NOT NULL ORDER BY id LIMIT 100"
      entries = []
      ImageEntry.uncached do
        entries = ImageEntry.find_by_sql(sql)
      end
      if entries.count > 0
      else # if
        raise "Done!"
      end
    end # while
  end # task

end
