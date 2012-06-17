require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'base64'

$folder = File.expand_path(File.dirname(__FILE__))

describe NSIVideoGranulate do

  before :all do
    @nsivideogranulate = NSIVideoGranulate::Client.new user: 'test', password: 'test',
                                           host: 'localhost', port: '9886'
    @fake_cloudooo = NSIVideoGranulate::FakeServerManager.new.start_server
  end

  after :all do
    @fake_cloudooo.stop_server
  end

  context "cannot connect to the server" do
    it "throws error if couldn't connec to the server" do
      nsivideogranulate = NSIVideoGranulate::Client.new user: 'test', password: 'test',
                                           host: 'localhost', port: '4000'
      expect { nsivideogranulate.granulate(:file => 'video', :filename => "teste.odt") }.to \
             raise_error(NSIVideoGranulate::Errors::Client::ConnectionRefusedError)
    end
  end

  context "simple granulation" do
    it "can send a video to be granulated by a nsivideogranulate node" do
      response = @nsivideogranulate.granulate(:file => 'video', :filename => 'video.ogv')
      response.should_not be_nil
      response["video_key"].should == "key for video video.ogv"
    end

    it "should throw error if any required parameter is missing" do
      expect { @nsivideogranulate.granulate(:file => 'video') }.to raise_error(NSIVideoGranulate::Errors::Client::MissingParametersError)
      expect { @nsivideogranulate.granulate(:cloudooo_uid => 'video') }.to raise_error(NSIVideoGranulate::Errors::Client::MissingParametersError)
      expect { @nsivideogranulate.granulate(:filename => 'video') }.to raise_error(NSIVideoGranulate::Errors::Client::MissingParametersError)
    end
  end

  context "granulation with conversion" do
    it "can send video in a closed format to be granulated by a cloudooo node" do
      response = @nsivideogranulate.granulate(:file => 'video', :filename => 'video.ogv')
      response.should_not be_nil
      response["video_key"].should == "key for video video.ogv"
    end
  end

  context "granulation with download" do
    it "can download videos from a link to be granulated by a cloudooo node" do
      response = @nsivideogranulate.granulate(:video_link => "http://video_link/video.ogv")
      response.should_not be_nil
      response["video_key"].should == "key for video video.ogv"
    end
  end

  context "granualtion with callback" do
    it "can send a video to be granulated by a cloudooo node and specify a callback url" do
      response = @nsivideogranulate.granulate(:file => 'video', :filename => 'video.ogv', :callback => 'http://google.com')
      response.should_not be_nil
      response["video_key"].should == "key for video video.ogv"
      response["callback"].should == 'http://google.com'
    end

    it "can send a video to be granulated by a cloudooo node and specify the verb" do
      response = @nsivideogranulate.granulate(:file => 'video', :filename => 'video.ogv', :callback => 'http://google.com', :verb => 'PUT')
      response.should_not be_nil
      response["video_key"].should == "key for video video.ogv"
      response["callback"].should == 'http://google.com'
      response["verb"].should == 'PUT'
    end
  end

  context "verify granulation" do
    it "can verify is a granulation is done or not" do
      key = @nsivideogranulate.granulate(:file => 'video', :filename => '2secs.odt')["video_key"]
      @nsivideogranulate.done(key)["done"].should be_false
      @nsivideogranulate.done(key)["done"].should be_true
      @nsivideogranulate.grains_keys_for(key)["images"].should have(0).images
      @nsivideogranulate.grains_keys_for(key)["files"].should have(0).files
    end

    it "can access the keys for all its grains" do
      key = @nsivideogranulate.granulate(:file => 'video', :filename => '2secs.odt')["video_key"]
      @nsivideogranulate.grains_keys_for(key)["images"].should have(0).images
      @nsivideogranulate.grains_keys_for(key)["files"].should have(0).files
    end

    it "raises an error when trying to verify if non-existing key is done" do
      expect { @nsivideogranulate.done("dont")["done"].should be_false }.to raise_error(NSIVideoGranulate::Errors::Client::KeyNotFoundError)
    end

    it "raises an error when the server can't connect to the queue service" do
      expect { @nsivideogranulate.granulate(:file => 'video', :filename => 'queue error' ).should be_false }.to raise_error(NSIVideoGranulate::Errors::Client::QueueServiceConnectionError)
    end

  end

  context "get configuration" do
    before do
      NSIVideoGranulate::Client.configure do
        user     "why"
        password "chunky"
        host     "localhost"
        port     "8888"
      end
    end

    it "by configure" do
      cloudooo = NSIVideoGranulate::Client.new
      cloudooo.instance_variable_get(:@user).should == "why"
      cloudooo.instance_variable_get(:@password).should == "chunky"
      cloudooo.instance_variable_get(:@host).should == "localhost"
      cloudooo.instance_variable_get(:@port).should == "8888"
    end

    it "by initialize parameters" do
      cloudooo = NSIVideoGranulate::Client.new(user: 'luckystiff', password: 'bacon', host: 'why.com', port: '9999')
      cloudooo.instance_variable_get(:@user).should == "luckystiff"
      cloudooo.instance_variable_get(:@password).should == "bacon"
      cloudooo.instance_variable_get(:@host).should == "why.com"
      cloudooo.instance_variable_get(:@port).should == "9999"
    end
  end

end

