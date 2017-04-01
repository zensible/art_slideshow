class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  before_filter :set_metadata

  def set_metadata
    @image = "#{request.protocol}#{request.host_with_port}/social.jpg"
    @pagename = "Fine Art Slideshow"
    @description = "A high-quality randomized slideshow of fine art from the Metropolitan Museum's more than 200,000 public domain works, including paintings, sculpture, drawings, photographs and more. Perfect for digital picture frames and just generally basking in the splendor of human artistic achievement."
    @keywords = "fine art, slideshow, met, the met, Metropolitan Museum, museum, paintings, sculpture, asian, american, modern art, egyptian art, arms, armor, medieval"
    @sitename = "art-slideshow.net"
  end

end
