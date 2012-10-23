module Split
  module Helper
    attr_accessor :ab_user

    def ab_test(experiment_name, control, *alternatives)
      puts 'WARNING: You should always pass the control alternative through as the second argument with any other alternatives as the third because the order of the hash is not preserved in ruby 1.8' if RUBY_VERSION.match(/1\.8/) && alternatives.length.zero?
      ret = if Split.configuration.enabled
              experiment_variable(alternatives, control, experiment_name)
            else
              control_variable(control)
            end

      if block_given?
        if defined?(capture) # a block in a rails view
          block = Proc.new { yield(ret) }
          concat(capture(ret, &block))
          false
        else
          yield(ret)
        end
      else
        ret
      end
    end

    def finished(experiment_name, options = {:reset => true})
      return if exclude_visitor? or !Split.configuration.enabled or !ab_user.is_confirmed?
      return unless (experiment = Split::Experiment.find(experiment_name))
      if alternative_name = ab_user.get_key(experiment.key)
        alternative = Split::Alternative.new(alternative_name, experiment_name)
        alternative.increment_completion unless ab_user.get_finished(experiment.key)
        ab_user.set_finished(experiment.key)
        if options[:reset]
          ab_user.delete_key(experiment.key)
          ab_user.delete_finished(experiment.key)
        end
        Split.redis.sadd("#{experiment.key}:finishers", ab_user.identifier)
      end
    rescue => e
      raise unless Split.configuration.db_failover
      Split.configuration.db_failover_on_db_error.call(e)
    end

    def override(experiment_name, alternatives)
      params[experiment_name] if defined?(params) && alternatives.include?(params[experiment_name])
    end

    def begin_experiment(experiment, alternative_name = nil)
      alternative_name ||= experiment.control.name
      ab_user.set_key(experiment.key, alternative_name)
    end

    def ab_user
      Split.user_store
    end

    def exclude_visitor?
      !allowed_user_agent? or is_robot? or is_ignored_ip_address?
    end

    def not_allowed_to_test?(experiment_key)
      !Split.configuration.allow_multiple_experiments && doing_other_tests?(experiment_key)
    end

    def doing_other_tests?(experiment_key)
      ab_user.get_keys.reject { |k| k == experiment_key }.length > 0
    end

    def clean_old_versions(experiment)
      old_versions(experiment).each do |old_key|
        ab_user.delete_key old_key
      end
    end

    def old_versions(experiment)
      if experiment.version > 0
        ab_user.get_keys.select { |k| k.match(Regexp.new(experiment.name)) }.reject { |k| k == experiment.key }
      else
        []
      end
    end

    def is_robot?
      Split.redis.hset("user agents", request.user_agent, request.user_agent =~ Split.configuration.robot_regex)
      Split.redis.incr("user agents:#{request.user_agent}")
      begin
        Split.redis.rpush("user agents:bots", request.user_agent) if request.user_agent =~ Split.configuration.robot_regex 
      rescue NameError
        puts 'Split Error: NameError'
      end

      begin
        request.user_agent =~ Split.configuration.robot_regex
      rescue NameError
        false
      end
    end

    def is_ignored_ip_address?
      begin
        if Split.configuration.ignore_ip_addresses.any?
          Split.configuration.ignore_ip_addresses.include?(request.ip)
        else
          false
        end
      rescue NameError
        false
      end
    end

    ##NEW INCLUDE METHOD

    def allowed_user_agent?
      allowed = false
      begin
        if Split.configuration.allowed_user_agent_regex
          allowed = !(request.user_agent =~ Split.configuration.allowed_user_agent_regex).nil?
        end
        allowed
      rescue NameError
        false
      end
    end

    def check_session
      has_sesh = nil
      begin
        has_sesh = session[:split]
      rescue
        puts 'SPLIT ERROR: No Session Found'
      end
      if has_sesh.blank?
        Split.redis.hset('bots', request.user_agent, exclude_visitor?)
      else
        Split.redis.hset('nonbots', request.user_agent, exclude_visitor?)
      end
    end

    protected

    def control_variable(control)
      Hash === control ? control.keys.first : control
    end

    def experiment_variable(alternatives, control, experiment_name)
      begin
        experiment = Split::Experiment.find_or_create(experiment_name, *([control] + alternatives))
        if experiment.winner
          ret = experiment.winner.name
        else
          if forced_alternative = override(experiment.name, experiment.alternative_names)
            ret = forced_alternative
          else
            clean_old_versions(experiment)
            begin_experiment(experiment) if exclude_visitor? or not_allowed_to_test?(experiment.key)

            if ab_user.get_key(experiment.key)
              ret = ab_user.get_key(experiment.key)
            else
              alternative = experiment.next_alternative
              if ab_user.is_confirmed?
                alternative.increment_participation
                Split.redis.hset("particication", request.user_agent, 1)
                Split.redis.incr("particication:#{request.user_agent}")
                Split.redis.lpush("particication:#{request.user_agent}:ab_users", ab_user.identifier)
                Split.redis.lpush("particication:#{request.user_agent}:ips", request.remote_ip)
              end
              begin_experiment(experiment, alternative.name)
              ret = alternative.name
            end
          end
        end
      rescue => e
        raise unless Split.configuration.db_failover
        Split.configuration.db_failover_on_db_error.call(e)
        ret = control_variable(control)
      end
      ret
    end

  end

end
