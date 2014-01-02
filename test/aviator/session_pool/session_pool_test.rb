require 'test_helper'

class Aviator::Test

  describe 'aviator/session_pool/session_pool' do

    def default_options
      {
        config_file: 'path/to/aviator.yml',
        environment: :production,
        log_file:    'path/to/aviator.log',
        redis_host:  'localhost',
        redis_port:   6379
      }
    end


    def redis
      @redis ||= Redis.new(host: default_options[:redis_host], port: default_options[:redis_port])
    end


    def session
      @session ||= Aviator::Session.new default_options
    end


    def subject
      Aviator::SessionPool
    end


    before do
      redis.flushdb

      # Reload Session mocks each time
      load 'support/aviator_session_mock.rb'

      subject.configure default_options
    end


    describe '::[]=' do

      it 'stores the session dump in redis' do
        key = 'somestring'

        subject[key] = session

        stored = redis.get(subject.send(:build_key, key))

        stored.wont_be_nil
        stored.must_equal session.dump
      end

    end # describe '::[]='


    describe '::[]' do

      it 'retrieves a previously stored session from redis' do
        key = 'somestring'

        subject[key] = session

        retrieved = subject[key]

        retrieved.class.must_equal Aviator::Session
        retrieved.dump.must_equal session.dump
      end


      it 'returns nil when a stored session is invalid' do
        key = 'somestring'

        subject[key] = session

        Aviator::Session.class_eval do
          def validate
            false
          end
        end

        subject[key].must_be_nil
      end


      it 'returns nil when the session does not exist' do
        subject['boguskey'].must_be_nil
      end

    end # describe '::[]'


    describe '::configure' do

      it 'sets the class\'s configuration' do
        opts = {
                 config_file: 'the quick',
                 environment: 'brown fox',
                 log_file:    'jumps over',
                 redis_host:  'the lazy',
                 redis_port:  'dog'
               }

        subject.configure opts

        subject.configuration.each{ |key, value| value.must_equal opts[key] }
      end

    end # describe '::configure'


    describe '::create' do

      it 'creates the session when called' do
        key = 'loadsessionkey'

        subject[key] = session

        subject.create(key).dump.wont_equal session.dump
      end

    end # describe '::create'


    describe '::get' do

      it 'aliases ::[]' do
        key = 'somestring'

        subject[key] = session

        subject.get(key).dump.must_equal subject[key].dump
      end

    end # describe '::get'


    describe '::get_current' do

      it 'raises an error if set_current was no previously called' do
        the_method = lambda do
          subject.get_current
        end

        the_method.must_raise Aviator::SessionPool::CurrentSessionNotDefinedError
      end

    end # describe '::get_current'


    describe '::get_or_create' do

      it 'loads a session if the associated session dump exists' do
        key = 'loadsessionkey'

        subject[key] = session

        subject.get_or_create(key).dump.must_equal session.dump
      end


      it 'creates a new session if one with the given key does not exist' do
        key = 'createsessionkey'

        subject.get_or_create(key).wont_be_nil
        subject.get_or_create(key).class.must_equal session.class
      end


      it 'creates a new session if one with the given key is invalid' do
        key = 'invalidsessionkey'

        subject[key] = session


        Aviator::Session.class_eval do
          def validate
            false
          end
        end


        subject.get_or_create(key).dump.wont_equal session.dump
      end


      it 'authenticates newly created sessions' do
        key = 'authenticatesnewsessionkey'

        session = subject.get_or_create(key)

        session.authenticated?.must_equal true
      end


      it 'passes on a block to the newly create session if provided' do
        key = 'passessonblocktosessionkey'

        session = subject.get_or_create(key) do |c|
          c.username = 'anything'
        end

        session.block_provided?.must_equal true
      end

    end # describe '::get_or_create'


    describe '::set_current' do

      it 'sets the current session' do
        key = 'setcurrentsessionkey'

        s = subject.get_or_create(key)

        subject.set_current(key)

        subject.get_current.dump.must_equal s.dump
      end


      it 'raises an error when the key does not exist' do
        key = 'setcurrentnonexistentsessionkey'

        the_method = lambda do
          subject.set_current(key)
        end

        the_method.must_raise Aviator::SessionPool::SessionNotFoundError
      end

    end # describe '::set_current'


    describe '::flush' do

      it 'deletes all keys in Redis that starts with the REDIS_KEY_PREFIX' do
        keys = ['somestring', 'anotherstring', 'wellthisisanotherstring']

        keys.each do |key|
          subject[key] = session

          key = subject.send(:build_key, key)
        end

        subject.flush

        keys.each{ |key| redis.get(key).must_be_nil }
      end

    end

  end

end
