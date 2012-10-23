module Split
  class RedisStore
    attr_accessor :redis
    attr_accessor :identifier
   
    def initialize(redis)
      @redis = redis
      @identifier = nil
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

    def confirm_js()
      puts "SPLIT::HELPER::AB_USER::CONFIRM_JS"
      puts @identifier
      if @redis.get("user_store:#{@identifier}:confirmed").nil?
        @redis.set("user_store:#{@identifier}:confirmed", true)
        keys = get_keys()
        keys.each do |key|
          exp = Split::Experiment.find(key)
          if exp
            alts = exp.alternatives
            chosen_alt = get_key(exp.key)
            alts.each{|alt| alt.increment_participation if alt.to_s == chosen_alt}
          end
        end
      end
    end

    def is_confirmed?()
      !@redis.get("user_store:#{@identifier}:confirmed").nil?
    end
  end
end
