require 'csv'
namespace :csv do
  task :import => :environment do
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

    objects = [
      "Painting",
      "Watercolor",
      "Sculpture",
      "Altarpiece",
      "Ball gown",
      "Bust",
      "Chalice",
      "Crown",
      "Dagger",
      "Dress",
      "Female figure",
      "Figure",
      "Funerary mask",
      "Mask",
      "Memorial painting",
      "Mihrab",
      "Model",
      "Mural",
      "Music stand",
      "Necklace",
      "Painted panel",
      "Panel",
      "Print",
      "Rapier",
      "Relief",
      "Saber",
      "Sculpture",
      "Set of jewelry",
      "Shield",
      "Sword",
      "Teapot",
      "Violoncello",
      "Violin"
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
end
