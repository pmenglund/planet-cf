require 'rubygems'
require 'bundler'

require 'sinatra'
require 'haml'
require 'sass'
require 'active_support'

$:.unshift(File.join(File.dirname(__FILE__), "lib"))
require 'feedzirra-redis'

FEEDS = [
  "http://blog.cloudfoundry.com/rss",
  "http://blog.codenursery.com/feeds/posts/default",
  "http://joyeur.com/category/for-developers/node-js/feed"
]

configure do
  options = { :adapter  => 'redis' }

  if services = ENV['VCAP_SERVICES']
    json = JSON.parse(services)
    credentials = json['redis-2.2'].first['credentials']
    options[:host] = credentials['hostname']
    options[:port] = credentials['port']
    options[:password] = credentials['password']
  end

  DataMapper.setup(:default, options)
  DataMapper.finalize

  # TODO ugly hack - move into a separate app
  Thread.new do
    while true
      puts "pulling feeds..."
      FEEDS.each do |feed|
        FeedzirraRedis::Feed.fetch_and_parse(feed)
      end
      sleep 600
    end
  end
end

# TODO add feed URL

get '/' do
  @entries = FeedzirraRedis::Entry.all(:order => [:published.desc])
  haml :index
end

get '/stylesheet.css' do
  headers 'Content-Type' => 'text/css; charset=utf-8'
  sass :stylesheet
end
