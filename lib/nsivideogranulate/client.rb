require "json"
require "net/http"
require File.dirname(__FILE__) + '/errors'
require File.dirname(__FILE__) + '/configuration'

module NSIVideoGranulate
  class Client

    # Initialize a client to a VideoGranulate node
    #
    # @param [Hash] options used to connect to the VideoGranulate node
    # @options options [String] host to connect
    # @options options [String] port to connect
    # @options options [String] user to authenticatie with
    # @options options [String] password to the refered user
    #
    # @return [Client] the object itself
    # @example
    #   videogranulate = NSIVideoGranulate::Client.new host: 'localhost', port: '8886', user: 'test', password: 'test'
    #
    # @note if you had used the 'configure' method, you can use it without parameters
    #       and those you provided before will be used (see Client#configure)
    def initialize(params = {})
      params = Configuration.settings.merge(params)
      @user = params[:user]
      @password = params[:password]
      @host = params[:host]
      @port = params[:port]
    end

    # Send a video be granulated by a nsi.videogranulate node
    #
    # @param [Hash] options used to send a video to be graulated
    # @option options [String] file the base64 encoded file to be granulated
    # @option options [String] sam_uid the UID of a video at SAM
    # @option options [String] filename the filename of the video
    # @note the filename is very importante, the videogranulate node will use the proper coding/encoding option for the video type
    # @option options [String] video_link link to the video that'll be granulated
    # @note if provided both video_link and file options, file will be ignored and the client will download the video instead
    # @option options [String] callback a callback url to the file granulation
    # @option options [String] verb the callback request verb, when not provided, nsi.videogranulate defaults to POST
    #
    # @example A simple granulation
    #   require 'base64'
    #   video = Base64.encode64(File.new('video.ogv', 'r').read)
    #   response = nsivideogranulate.granulate(:file => video, :filename => 'video.ogv')
    #   nsivideogranulate.done(response["video_key"])
    #   nsivideogranulate.grains_keys_for(response["video_key"])
    # @example Granulating from a SAM uid
    #   video = Base64.encode64(File.new('video.ogv', 'r').read)
    #   response = sam.store({:doc => doc})
    #   video_key = response["key"]
    #   response = nsivideogranulate.granulate(:sam_uid => video_key, :filename => 'video.ogv')
    #   nsivideogranulate.done(response["video_key"])
    #   nsivideogranulate.grains_keys_for(response["video_key"])
    # @example Downloading and granulating from web
    #   response = nsivideogranulate.granulate(:video_link => 'http://google.com/video.ogv')
    #   nsivideogranulate.done(response["video_key"])
    #   nsivideogranulate.grains_keys_for(response["video_key"])
    # @example Sending a callback url
    #   video = Base64.encode64(File.new('video.ogv', 'r').read)
    #   nsivideogranulate.granulate(:file => video, :filename => 'video.ogv', :callback => 'http://google.com')
    #   nsivideogranulate.granulate(:video_link => 'http://google.com/video.ogv', :callback => 'http://google.com')
    # @example Using a custom verb to the callback
    #   video = Base64.encode64(File.new('video.ogv', 'r').read)
    #   nsivideogranulate.granulate(:file => video, :filename => 'video.ogv', :callback => 'http://google.com', :verb => "PUT")
    #   nsivideogranulate.granulate(:video_link => 'http://google.com/video.ogv', :callback => 'http://google.com', :verb => "PUT")
    #
    # @return [Hash] response
    #   * "video_key" [String] the key to access the granulated video in the sam node it was stored
    #
    # @raise NSIVideoGranulate::Errors::Client::MissingParametersError when an invalid or incomplete set of parameters is provided
    # @raise NSIVideoGranulate::Errors::Client::SAMConnectionError when cannot connect to the SAM node
    # @raise NSIVideoGranulate::Errors::Client::AuthenticationError when invalids user and/or password are provided
    # @raise NSIVideoGranulate::Errors::Client::KeyNotFoundError when an invalid sam_uid is provided
    #
    def granulate(options = {})
      @request_data = Hash.new
      if options[:video_link]
        insert_download_data options
      elsif options[:sam_uid] && options[:filename]
        file_data = {:video_uid => options[:sam_uid], :filename => options[:filename]}
        @request_data.merge! file_data
      elsif options[:file] && options[:filename]
        file_data = {:video => options[:file], :filename => options[:filename]}
        @request_data.merge! file_data
      else
        raise NSIVideoGranulate::Errors::Client::MissingParametersError
      end
      insert_callback_data options
      request = prepare_request :POST, @request_data.to_json
      execute_request(request)
    end

    # Verify if a video is already granulated
    #
    #
    # @param [String] key of the desired video
    # @return [Hash] response
    #   * "done" [String] true if the video was already granualted, otherwise, false
    #
    # @example
    #   nsivideogranulate.done("some key")
    #
    # @raise NSIVideoGranulate::Errors::Client::SAMConnectionError when cannot connect to the SAM node
    # @raise NSIVideoGranulate::Errors::Client::AuthenticationError when invalids user and/or password are provided
    # @raise NSIVideoGranulate::Errors::Client::KeyNotFoundError when an invalid key is provided
    #
    def done(key)
      request = prepare_request :GET, {:key => key}.to_json
      execute_request(request)
    end

    # Return the keys of the grains of a video
    #
    #
    # @param [String] key of the desired video
    # @return [Hash] response
    #   * "images" [String] keys to the images grains of the video
    #   * "files" [String] keys to the files grains of the video
    #
    # @example
    #   nsivideogranulate.grains_keys_for("some key")
    #
    # @raise NSIVideoGranulate::Errors::Client::SAMConnectionError when cannot connect to the SAM node
    # @raise NSIVideoGranulate::Errors::Client::AuthenticationError when invalids user and/or password are provided
    # @raise NSIVideoGranulate::Errors::Client::KeyNotFoundError when an invalid key is provided
    #
    def grains_keys_for(video_key)
      request = prepare_request :GET, {:video_key => video_key, :grains => true}.to_json
      execute_request(request).select { |key| ['images', 'videos'].include? key }
    end

    def thumbnail_key_for(video_key)
      request = prepare_request :GET, {:video_key => video_key, :grains => true}.to_json
      execute_request(request).select { |key| 'thumbnail' == key }
    end

    def audio_key_for(video_key)
      request = prepare_request :GET, {:video_key => video_key, :grains => true}.to_json
      execute_request(request).select { |key| 'audio' == key }
    end

    def converted_video_key_for(video_key)
      request = prepare_request :GET, {:video_key => video_key, :grains => true}.to_json
      execute_request(request).select { |key| 'converted_video' == key }
    end

    # Pre-configure the NSIVideoGranulate module with default params for the NSIVideoGranulate::Client
    #
    # @yield a Configuration object (see {NSIVideoGranulate::Client::Configuration})
    #
    # @example
    #   NSIVideoGranulate::Client.configure do
    #     user     "why"
    #     password "chunky"
    #     host     "localhost"
    #     port     "8888"
    #   end
    def self.configure(&block)
      Configuration.instance_eval(&block)
    end

    private

    def insert_download_data(options)
      download_data = {video_link: options[:video_link]}
      @request_data.merge! download_data
    end

    def insert_callback_data(options)
        @request_data[:callback] = options[:callback] unless options[:callback].nil?
        @request_data[:verb] = options[:verb] unless options[:verb].nil?
    end

    def prepare_request(verb, body)
      verb = verb.to_s.capitalize!
      request = Net::HTTP.const_get("#{verb}").new '/'
      request.body = body
      request.basic_auth @user, @password
      request
    end

    def execute_request(request)
      begin
        response = Net::HTTP.start @host, @port do |http|
          http.request(request)
        end
      rescue Errno::ECONNREFUSED => e
        raise NSIVideoGranulate::Errors::Client::ConnectionRefusedError
      else
        raise NSIVideoGranulate::Errors::Client::KeyNotFoundError if response.code == "404"
        raise NSIVideoGranulate::Errors::Client::MalformedRequestError if response.code == "400"
        raise NSIVideoGranulate::Errors::Client::AuthenticationError if response.code == "401"
        raise NSIVideoGranulate::Errors::Client::QueueServiceConnectionError if response.code == "503"
        if response.code == "500" and response.body.include?("SAM")
          raise NSIVideoGranulate::Errors::Client::SAMConnectionError
        end
        JSON.parse(response.body)
      end
    end
  end
end
