require 'csv'
require 'digest/md5'
require 'uri'
require 'fileutils'

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
    abort "DONE!"
  end

  # Step 2: populate url_jpeg and met_html
  task :get_url_html => :environment do
    sleep_time = 0.1
    offset = ENV['OFFSET'] || "0"
    while true
      sql = "SELECT * FROM image_entries WHERE url_jpeg IS NULL AND id > #{offset} ORDER BY id LIMIT 100"
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
        abort "Done!"
      end
    end # while
  end # task

  # Step 3: download and process images
  task :download => :environment do
    sleep_time = 0.1

    offsetSta = ENV['OFFSETSTA'] || "0"
    offsetEnd = ENV['OFFSETEND'] || "100000000"

    while true
      sql = "SELECT * FROM image_entries WHERE id > #{offsetSta} AND id < #{offsetEnd} AND url_jpeg IS NOT NULL AND md5 IS NULL ORDER BY id LIMIT 100"
      entries = []
      ImageEntry.uncached do
        entries = ImageEntry.find_by_sql(sql)
      end
      if entries.count > 0
        entries.each do |entry|
          url = URI.escape(entry.url_jpeg)

          #begin
            fn_in = "#{entry.object_id}-full.jpg"
            path_in = "./public/downloaded/archive/#{fn_in}"
            puts "== path: #{path_in}"
            File.delete path_in if File.exist? path_in
            if !File.exist? path_in
              cmd = "curl -g -o '#{path_in}' '#{url}'"
              puts cmd
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

            first_two = entry.md5.slice(0, 2)
            dir_path = "./public/archive/#{first_two}"
            if !Dir.exist?(dir_path)
              Dir.mkdir(dir_path)
            end
            path_out = dir_path + "/" + fn_out

            if !File.exist? path_out
              puts "Out: #{path_out}"
              if wid > hei
                FastImage.resize(path_in, 1800, 0, :outfile => path_out)
              else
                FastImage.resize(path_in, 0, 1800, :outfile => path_out)
              end
            end
          #rescue Exception => ex
          #  if ex.to_s == "Interrupt"
          #    abort "Done"
          #  end
          #  puts ex.inspect
          #  entry.md5 = nil
          #  entry.save
          #end
        end
      else # if
        abort "Done!"
      end
    end # while
  end # task

  task :cleanup => :environment do

    # The jpegs for these entries are corrupt, skip them entirely
    miscreants = [ 42137, 49978, 166834, 167170, 167680, 167681, 167682, 172426, 166834, 167170, 167680, 167681, 167682, 172426, 384014 ] 
    miscreants.each do |id|
      sql = "DELETE FROM image_entries WHERE object_id = #{id}"
      ActiveRecord::Base.connection.execute(sql)
    end

    # There is no image for these records
    no_image = [ 97123, 100435, 100542, 100543, 100544, 123371, 147110, 147667, 149167, 149168, 149169, 149176, 149177, 149178, 149219, 158171, 171556, 172775, 172833, 172954, 172955, 172956, 172957, 172974, 173000, 173001, 173098, 173151, 173355, 173356, 173818, 173829, 173832, 173891, 173913, 173933, 174035, 174927, 174952, 175324, 175325, 175346, 175409, 175415, 175772, 175773, 175774, 175812, 175819, 175820, 175830, 175831, 175835, 175893, 175895, 175896, 175977, 175978, 175979, 175980, 175981, 175982, 175983, 175984, 175985, 175986, 175987, 175988, 175990, 175991, 175992, 175993, 176227, 176228, 176290, 176376, 176788, 176802, 176844, 176938, 177507, 177508, 177509, 177510, 178114, 178156, 178175, 178180, 178237, 178261, 178307, 178311, 178312, 178313, 178315, 178345, 178347, 178349, 178350, 178351, 178352, 178353, 178354, 178355, 178356, 178366, 178416, 178447, 178448, 178451, 178801, 178815, 178816, 178839, 178843, 178844, 178846, 178849, 178850, 178885, 178890, 178924, 178925, 178926, 178950, 178976, 179303, 179308, 179309, 179314, 179496, 179497, 179560, 179561, 179562, 179563, 179564, 179740, 179845, 179846, 179847, 179848, 179849, 179850, 179851, 179852, 179853, 179854, 179855, 179856, 179857, 179858, 179859, 179860, 179861, 179862, 179874, 179875, 179876, 179877, 179878, 179879, 180196, 180197, 180198, 180373, 180852, 180853, 180858, 180859, 180867, 180984, 180995, 181064, 181085, 181681, 181682, 181683, 181684, 181685, 181686, 181687, 181688, 181689, 181690, 181691, 181692, 181693, 181694, 181708, 181709, 182203, 182205, 182217, 182218, 182223, 182224, 182225, 182226, 182227, 182228, 182272, 182273, 182274, 182276, 182379, 182380, 182400, 182401, 182402, 182404, 182405, 182409, 182419, 182420, 182421, 182422, 182424, 182425, 182431, 182432, 182515, 182525, 182526, 182527, 182528, 182532, 182549, 182788, 182820, 182873, 182987, 183044, 183045, 183047, 183143, 183144, 183256, 183275, 183276, 183277, 183278, 183279, 183281, 183295, 183304, 183392, 183393, 183547, 183548, 183549, 183550, 183551, 183552, 183553, 183554, 183555, 183556, 183557, 183657, 183658, 183659, 183660, 183661, 183662, 183663, 183664, 183665, 183666, 183667, 183668, 183669, 183856, 183857, 183926, 184147, 184154, 184301, 184466, 184473, 184474, 184475, 190991, 191486, 191488, 191490, 191491, 191492, 191493, 191494, 191495, 191496, 191497, 191498, 191499, 191841, 192154, 193461 ]
    no_image.each do |id|
      sql = "DELETE FROM image_entries WHERE id = #{id}"
      ActiveRecord::Base.connection.execute(sql)
    end

    # These had >25 database entries for the same image. They're almost all 'pottery fragments' or 'door hinges', so super boring, kill 'em off. Prevents them from showing up far too often when on random
    hella_dupes = [ 'a0168ed49e3a03ff769fe71382f862b9', 'ba704ea1053a8627d95da0ed3fae2f7a', '475e4ee332988c5d9e9e654fdb597786', '9a776f3784ff7c5d5daf43f3917ed701', '693f38389ce983a4d92adeb54a2812c3', '23cdce7efb0ca4fc58760e1a3fb20d36', '09349231c93339f860dfb406e3c9003f', 'ff8de8f2abe37b2f0301105cf5f6e863', '9d51237d8dac9c483f88e0920142bb3b', 'a364eac5721c0c7f98f8dfaddc138f43', '4fd55680979d38c9fb1cb6fa5da0a76d', '47cdf2f41512a786c388f7ac7748c734', '3de7bc1421ff7eca7ecf05d2b414a74e', '5f27831a4d68ee544cb2624cc35c0273', 'ce075f985d67e335e46117e74c2aace0' ]
    hella_dupes.each do |id|
      sql = "DELETE FROM image_entries WHERE md5 = '#{id}'"
      ActiveRecord::Base.connection.execute(sql)
    end

    # This is the met's 'sorry we're under maintenance' page. When I downloaded all images, there were 98 of these.
    sql = "DELETE FROM image_entries WHERE md5 = '5343c1a8b203c162a3bf3870d9f50fd4'"
    ActiveRecord::Base.connection.execute(sql)
  end

  task :fix_resized_larger_original => :environment do
    sql = "SELECT * FROM image_entries WHERE md5 IS NOT NULL ORDER BY id"
    entries = []
    ImageEntry.uncached do
      entries = ImageEntry.find_by_sql(sql)
    end
    entries.each do |entry|
      fn_orig = "#{entry.object_id}-full.jpg"
      path_orig = "./public/downloaded/archive/#{fn_orig}"

      fn_resized = entry.md5 + ".jpg"
      first_two = entry.md5.slice(0, 2)
      path_resized = "./public/archive/#{first_two}" + "/" + fn_resized

      if File.exist?(path_resized)
        if File.size(path_resized) > File.size(path_orig)
          puts "ALERRRRT #{path_resized} [#{File.size(path_resized)}] orig: #{path_orig} [#{File.size(path_orig)}]"
          File.delete(path_resized)
          FileUtils.cp(path_orig, path_resized)
        end
      else
        puts "File DNE: #{path_resized}. Please re-run csv:download"
        entry.md5 = nil
        entry.save
      end
    end
  end

  task :metadata => :environment do
    sleep_time = 0.1

    sql = "SELECT distinct(md5) FROM image_entries order by md5"
    results = ActiveRecord::Base.connection.execute(sql)

    cnt = -1
    results.each do |row|
      cnt += 1
      md5 = row[0]
      next if md5.nil?
      puts md5 if cnt % 100 == 0
      first_two = md5.slice(0, 2)
      dest_path = "./public/archive/#{first_two}/#{md5}.jpg"

      if File.exist? dest_path
        arr = FastImage.size(dest_path)
        next if arr.nil?
        wid = arr[0]
        hei = arr[1]
        kbytes = (File.size(dest_path) / 1000).to_i
        sql = "UPDATE image_entries SET width = #{wid}, height = #{hei}, kbytes = #{kbytes} WHERE md5 = '#{md5}'"
        ActiveRecord::Base.connection.execute(sql)
      end
    end
    abort "Done"
  end # task

  # Step 4: upload to s3
  # Note to self: for creds search scratch for: s3 upload
  task :upload_to_s3 => :environment do
    sql = "SELECT * FROM image_entries WHERE host_me = 0 AND kbytes > 50"
    entries = []
    ImageEntry.uncached do
      entries = ImageEntry.find_by_sql(sql)
    end

    client = Aws::S3::Client.new(region: 'us-west-2')
    s3 = Aws::S3::Resource.new(client: client)

    entries.each do |entry|
      md5 = entry.md5
      first_two = md5.slice(0, 2)
      dest_path = "./public/archive/#{first_two}/#{md5}.jpg"
      key = "#{first_two}/#{md5}.jpg"
      s3.bucket('met-slideshow').object(key).upload_file(dest_path)
      entry.host_me = 1
      entry.save
    end
  end # task

end
