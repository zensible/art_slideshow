class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  before_filter :set_metadata

  def set_metadata
    @description = "A slideshow of the more than 200,000 public domain images released by the Metropolitan Museum of New York"
    @keywords = "art, slideshow, met, the met, Metropolitan Museum, museum, paintings, sculpture, asian, american, modern art, egyptian art, arms, armor, medieval"
    @pagename = "Fine Art Slideshow - 186,000 public domain works of art at random"
    @image = "#{request.protocol}#{request.host_with_port}/social.jpg"
    @sitename = "jsante.net"  
  end

end
