require 'redis'

module Aviator
  class SessionPool

    class CurrentSessionNotDefinedError < StandardError
      def initialize
        super "Current session is not defined. Make sure to call ::set_current first."
      end
    end

    class SessionNotFoundError < StandardError
      def initialize(key)
        super "There is no session with key #{ key } in the pool"
      end
    end


    REDIS_KEY_PREFIX = 'aviator.session_dumps'

    class << self

      def []=(key, session)
        session_key = build_key(key)

        redis.set(session_key, session.dump)
      end


      def [](key)
        session_dump = redis.get(build_key(key))

        return nil unless session_dump

        session = Aviator::Session.load(session_dump)

        session.validate ? session : nil
      end
      alias :get :[]


      # Not thread safe! BUT good enough for
      # a single-threaded web application.
      def configure(options)
        @configuration = options

        # So that the redis configuration will
        # be reloaded on the next ::redis call
        @redis = nil
      end
      attr_reader :configuration
      alias :c :configuration


      def create(key, &block)
        config = configuration.dup
        [:redis_host, :redis_port].each{|k| config.delete k }
        session = Aviator::Session.new(config)

        session.authenticate &block

        self[key] = session
      end


      # WARNING: Since get_current uses a class instance variable, it will contain
      # a value between http requests whether set_current was called or not for as long
      # as it was called at least once.
      def get_current
        self.get(@current_key) || (raise CurrentSessionNotDefinedError.new)
      end


      def get_or_create(key, &block)
        # If session is invalid or does not exist, self[] will return nil
        self.get(key) || self.create(key, &block)
      end


      # Not thread safe! BUT good enough for
      # a single-threaded web application.
      def set_current(key)
        raise SessionNotFoundError.new(key) unless self.get(key)

        @current_key = key
      end


      def flush
        redis.keys("#{ REDIS_KEY_PREFIX }*").each{ |key| redis.del(key) }
      end


      private

      def build_key(key)
        "#{ REDIS_KEY_PREFIX }.#{ key }"
      end

      def redis
        @redis ||= Redis.new(host: c[:redis_host], port: c[:redis_port])
      end

    end

  end
end
