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

  # TODO ugly hack - move into a separate app and run hourly using clockwork
  index = 0
  if app_env = ENV['VCAP_APPLICATION']
    json = JSON.parse(app_env)
    index = json['instance_index']
  end

  # only start the update thread on the first instance
  if index == 0
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

end

get '/' do
  @entries = FeedzirraRedis::Entry.all(:order => [:published.desc])
  haml :index
end

get '/stylesheet.css' do
  headers 'Content-Type' => 'text/css; charset=utf-8'
  sass :stylesheet
end

get '/about' do
  haml :about
end

get '/feed' do
  # TODO caching
  @entries = FeedzirraRedis::Entry.all(:order => [:published.desc])
  content_type 'application/rss+xml'
  haml :feed, :format => :xhtml, :escape_html => true, :layout => false
end
