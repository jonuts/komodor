module Komodor
  class Server
    def initialize(host, port)
      @server = TCPServer.new(host, port)
      @config = Komodor.config
      @queues = {}
    end

    attr_reader :server, :config, :queues

    def run!
      loop do
        Thread.start(server.accept) do |sock|
          begin
            data   = JSON.load(sock.gets.chomp)
            request = Request.new(self, data)
            Komodor.write(:info, "connected :: #{data.inspect}")

            resp = if respond_to?(request.action)
              send(request.action, request)
            else
              request.queue.send(request.action, *request.args)
            end
            sock.puts(YAML.dump(response: resp))
          rescue => e
            Komodor.write(:error, "[ERRROR] #{[e.class, e.message].join(" ~> ")}")
          ensure
            sock.close
          end
        end
      end
    end

    def protect(req)
      Herd.protect!
      Herd.runners
    end

    def quit(req)
      queues.values.each do |herd|
        herd.stop
      end
      FileUtils.rm config.pidfile if File.exists?(config.pidfile)
      exit 0
    end

    def get(req)
      req.queue
    end

    def remove(req)
      req.queue.stop
      queues.delete(req.key)
      queues
    end

    def set(req)
      queues[req.key] = Herd[req.key] unless req.queue
      queues
    end
  end
end
