class ImageEntry < ActiveRecord::Base
  def url
    fn_out = self.md5 + ".jpg"

    first_two = self.md5.slice(0, 2)
    dir_path = "./public/archive/#{first_two}"
    return "https://s3-us-west-2.amazonaws.com/met-slideshow/#{first_two}/#{fn_out}"
  end

  def attributes
    attrs = super.merge({ :url => self.url() })
    attrs.delete("met_html")
    attrs["full_description"] = JSON.load(attrs["full_description"])
    return attrs
  end
end