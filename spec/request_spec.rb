require "spec_helper"

describe Komodor::Request do
  before do
    @server = Komodor::Server.new('localhost', 60111)
    @server.queues[:foo] = OpenStruct
  end

  after do
    @server.queues.delete(:foo)
    @server.server.close
  end

  context "valid request" do
    before do
      opts = JSON.dump({
        action: 'foo',
        queue: :foo,
        args: [:arg1, :arg2],
        whatever: 'hello'
      })
      @req = Komodor::Request.new(@server, JSON.load(opts))
    end

    it "stores queues key" do
      @req.key.should eql(:foo)
    end

    it "has a queue" do
      @req.queue.should eql(OpenStruct)
    end

    it "stores the action" do
      @req.action.should eql('foo')
    end

    it "stores args" do
      @req.args.should eql(%w(arg1 arg2))
    end

    it "allows access to extra args" do
      @req.whatever.should eql("hello")
    end
  end
end
