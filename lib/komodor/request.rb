module Komodor
  class Request
    def initialize(server, data={})
      @server = server
      @action = data.delete('action')
      @key    = data.delete('queue')
      @key    = @key.to_sym if @key
      @args   = data.delete('args')
      @data   = data
    end

    attr_reader :action, :args, :key

    def queue
      @server.queues[@key] if @key
    end

    def method_missing(meth, *args, &blk)
      @data[meth.to_s]
    end
  end
end
