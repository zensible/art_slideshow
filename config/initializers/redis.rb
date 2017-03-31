$redis_config = {}
$redis_config = YAML.load_file(Rails.root + 'config/redis.yml')[Rails.env]
require "redis"

$redis = Redis.new(:host => $redis_config['host'], :port => $redis_config['port'], :db => $redis_config['db'])

$redis.set('loaded', 'asdf')
