module Split
  class Configuration
    attr_accessor :robot_regex
    attr_accessor :allowed_user_agent_regex
    attr_accessor :ignore_ip_addresses
    attr_accessor :db_failover
    attr_accessor :db_failover_on_db_error
    attr_accessor :allow_multiple_experiments
    attr_accessor :enabled
    attr_accessor :user_store
    attr_accessor :user_identifier

    def initialize
      @robot_regex = /\b(Baidu|Gigabot|Googlebot|libwww-perl|lwp-trivial|msnbot|SiteUptime|Slurp|WordPress|ZIBB|ZyBorg)\b/i
      @allowed_user_agent_regex = nil
      @ignore_ip_addresses = []
      @db_failover = false
      @db_failover_on_db_error = proc{|error|} # e.g. use Rails logger here
      @allow_multiple_experiments = false
      @enabled = true
      @user_store = :session_store
      @user_identifier = nil # a proc for determining the user scope if not using sessions
    end
  end
end
