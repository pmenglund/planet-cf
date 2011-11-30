# grabbed from: https://github.com/logankoester/feedzirra-redis

%w{rubygems feedzirra dm-core dm-redis-adapter}.each { |f| require f }

module FeedzirraRedis

  class Entry
    include DataMapper::Resource
    property :id,           Serial
    property :guid,         String, :index => true
    property :title,        String
    property :url,          String
    property :author,       String
    property :summary,      Text, :lazy => false
    property :content,      Text, :lazy => false
    property :published,    Time, :index => true

    belongs_to :feed
  end

  class Feed
    include DataMapper::Resource
    property :id,            Serial
    property :title,         String
    property :url,           String
    property :feed_url,      String, :index => true
    property :etag,          String
    property :last_modified, DateTime

    has n, :entries

    def add_entries(entries)
      entries.each do |entry|
        unique_id = entry.id || entry.url
        redis_entry = Entry.first_or_create( {:guid => unique_id}, {
          :title        => entry.title,
          :url          => entry.url,
          :author       => entry.author,
          :summary      => entry.summary,
          :content      => entry.content,
          :published    => entry.published,
          :feed         => self
        })
      end
    end

    def self.fetch_and_parse(urls, options = {})
      if urls.is_a?(String)
        feed = Feedzirra::Feed.fetch_and_parse(urls, options)
        update_redis_from feed
      elsif urls.is_a?(Array)
        feeds = Feedzirra::Feed.fetch_and_parse(urls, options)
        redis_feeds = {}
        feeds.map do |feed|
          redis_feed = update_redis_from feed
          redis_feeds.merge!(redis_feed.feed_url => redis_feed)
        end
      else
        raise "Unexpected urls class #{urls.class}"
      end
    end

    # Delegate for compatibility
    def self.update(feeds, options = {})
      feeds.is_a?(Array) ? urls = feeds.map { |f| f.feed_url } : urls = feeds.feed_url
      self.fetch_and_parse(urls, options)
    end

  private
    def self.update_redis_from(feed)
      redis_feed = Feed.first_or_create(:feed_url => feed.feed_url)
      redis_feed.update({
        :title         => feed.title,
        :url           => feed.url,
        :etag          => feed.etag,
        :last_modified => feed.last_modified
      })
      redis_feed.add_entries(feed.entries)
      redis_feed.save
      return redis_feed
    end
  end

end
