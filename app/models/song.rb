# A hype machine song : storing its details and the users who favorited it 
class Song < RedisRecord

  EXPIRE_AFTER = 1.day
  DEFAULT_CRAWL_DEPTH = 2 # Enough to get one-level recommendations
  
  include Crawlable

  crawlable do 
    expire_after EXPIRE_AFTER
    default_depth DEFAULT_CRAWL_DEPTH
    crawl_with SongCrawler
  end
  
  # TODO : async sync! on favorites and recommendations

  has_attributes :synced_at,
                 :recommended_at, 
                 :recommendations,
                 :recommendations_built_at,
                 :artist,
                 :title

  has_associated :favorites

  def recommended_songs
    recommendations ? JSON.parse(recommendations).map{|song_id| Song.new(song_id)} : []
  end

  def user_ids
    favorites.exists ? favorites.smembers : []
  end
  
  def users
    user_ids.map{|user_id|User.new(user_id)}
  end

  # Jobs builders
  def synced?
    !!synced_at && ( Time.parse(synced_at) > (Time.now - EXPIRE_AFTER))
  end
  
  def sync!
    Resque.enqueue(SongSyncer, {"id" => self.id})
  end
  

  def recommendations_exist?
    !!recommendations
  end
  
  def recommendations_expired?
    recommendations_built_at && ( Time.parse(recommendations_built_at) > Time.now - EXPIRE_AFTER )
  end
  
  def build_recommendations!
    Resque.enqueue(Recommender, self.id)
  end
  
end