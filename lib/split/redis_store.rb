module Split
  class RedisStore
    attr_accessor :redis
    attr_accessor :identifier
    attr_accessor :user_agent
   
    def initialize(redis, session)
      raise SessionNotFoundError if session.nil?
      @redis = redis
      @identifier = nil
      @user_agent = nil
    end

    def get_key(name)
      @redis.hget("user_store:#{@identifier}", name)
    end

    def set_key(name, value)
      @redis.hset("user_store:#{@identifier}", name, value)
    end

    def get_keys
      @redis.hkeys("user_store:#{@identifier}")
    end

    def delete_key(name)
      @redis.hdel("user_store:#{@identifier}", name)
    end

    def to_hash
      @redis.hgetall("user_store:#{@identifier}")
    end

    def get_finished(name)
      @redis.hget("user_store:#{@identifier}:finished", name)
    end

    def set_finished(name, value=true)
      @redis.hset("user_store:#{@identifier}:finished", name, value)
    end

    def get_finished_keys
      @redis.hkeys("user_store:#{@identifier}:finished")
    end

    def delete_finished(name)
      @redis.hdel("user_store:#{@identifier}:finished", name)
    end

    def set_id(id)
      @identifier = id.to_s
    end

    def set_user_agent(agent)
      @user_agent = agent
    end

    class SessionNotFoundError < StandardError
    end
    
  end
end
