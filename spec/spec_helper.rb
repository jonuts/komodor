require 'bundler/setup'
Bundler.require :default, :test
require File.expand_path("../../lib/komodor", __FILE__)

RSpec.configure do |conf|
  conf.before(:suite) do
    require 'logger'
    Komodor.config do |config|
      config.logger = Logger.new("/tmp/komodor.test.log")
      config.port = 60002
    end
  end
end
