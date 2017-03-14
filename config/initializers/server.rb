ip = Socket.ip_address_list.detect{|intf| intf.ipv4_private?}
if ip.nil?
  raise "Error 1000: Could not find a local IP address. Is this machine connected to a local network?"
end
ip = ip.ip_address
$ip_address = ip

if ARGV[2] == '-p'
  $port = ARGV[3].to_i
else
  $port = 3000
end

if $port == 80
  $http_address_local = "http://#{ip}"
else
  $http_address_local = "http://#{ip}:#{$port}"
end

puts "\n\nSuccess! You may access the slideshow at this address on the local network:\n\n#{$http_address_local}\n\n"

