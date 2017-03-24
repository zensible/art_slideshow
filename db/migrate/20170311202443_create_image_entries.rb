class CreateImageEntries < ActiveRecord::Migration[5.0]
  def change
    create_table :image_entries do |t|
      t.string :object_number
      t.boolean :is_highlight
      t.boolean :is_public_domain
      t.integer :object_id
      t.string :department
      t.string :object_name
      t.string :title
      t.string :culture
      t.string :period
      t.string :dynasty
      t.string :reign
      t.string :portfolio
      t.string :artist_role
      t.string :artist_prefix
      t.string :artist_display_name
      t.string :artist_display_bio
      t.string :artist_suffix
      t.string :artist_alpha_sort
      t.string :artist_nationality
      t.integer :artist_begin_date
      t.integer :artist_end_date
      t.string :object_date
      t.integer :object_begin_date
      t.integer :object_end_date
      t.string :medium
      t.string :dimensions
      t.string :credit_line
      t.string :geography_type
      t.string :city
      t.string :state
      t.string :county
      t.string :country
      t.string :region
      t.string :subregion
      t.string :locale
      t.string :locus
      t.string :excavation
      t.string :river
      t.string :classification
      t.string :rights_and_reproduction
      t.string :link_resource
      t.string :metadata_date
      t.string :repository
      t.integer :downloaded, :default => 0
      t.text :met_html, :limit => 16.megabytes - 1
      t.string :md5
    end


    sql = "CREATE INDEX department_index ON image_entries (department)"
    ActiveRecord::Base.connection.execute(sql)

    sql = "CREATE INDEX object_end_date_index ON image_entries (object_end_date)"
    ActiveRecord::Base.connection.execute(sql)
  end
end

