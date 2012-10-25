module Split
  class RedisStore
    attr_accessor :redis
    attr_accessor :identifier
    attr_accessor :robot_override
   
    def initialize(redis)
      @redis = redis
      @identifier = nil
      @robot_override = false
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

    def set_id(id, robot_override = false)
      @identifier = id.to_s
      @robot_override = robot_override
    end

    def confirm_js(user_agent, remote_ip)
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
            alts.each do |alt|
              if alt.to_s == chosen_alt
                alt.increment_participation
                puts "RedisStore: pre save participation data"
                puts user_agent
                puts @identifier
                puts remote_ip
                Split::Alternative.save_participation_data(user_agent, @identifier, remote_ip)
              end
            end
          end
        end
      end
    end

    def is_confirmed?()
      !@redis.get("user_store:#{@identifier}:confirmed").nil?
    end
  end
end
