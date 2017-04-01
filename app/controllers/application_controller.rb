class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  before_filter :set_metadata

  def set_metadata
    @description = "Art Slideshow"
    @keywords = "art, slideshow, met, the met, Metropolitan Museum, museum"
    @pagename = "Art Slideshow"
    @image = "#{request.protocol}#{request.host_with_port}/arcade/arcade_preview.jpg"
    @sitename = "jsante.net"  
  end

end
