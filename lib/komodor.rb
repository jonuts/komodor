require "socket"
require "yaml"
require "json"
require "thread"
require "ostruct"
require "bundler/setup"
Bundler.require :default
require_relative "komodor/herd"

module Komodor
  class << self
    attr_accessor :server_spawned

    def config
      @config ||= OpenStruct.new
      yield @config if block_given?
      @config
    end

    def srvlock
      @srvlock ||= Mutex.new
    end

    def write(lvl, stuff)
      if config.logger
        config.logger.send(lvl, stuff)
      elsif config.suppress_output
        STDOUT.puts stuff
      end
    end

    def [](key)
      send_data({
        queue: key,
        action: :get
      })
    end

    def <<(key)
      send_data({
        queue: key,
        action: :set
      })
    end

    def startd!
      if running?
        write :info, "[komodor] running. pid #{File.read(config.pidfile)}"
        exit 0
      end

      pid = Process.fork do
        $0 = "[komodor]"
        start!
      end

      File.open(config.pidfile, 'w') {|f| f.puts pid}
      write :info, "[komodor] running. pid #{pid}"
    end

    def start!
      srv_thread = Thread.new {spawn_server}
      until server_spawned?
        sleep 0.2
      end
      send_data(action: 'protect')
      srv_thread.join
    end

    def server_spawned?
      srvlock.synchronize do
        !!@server_spawned
      end
    end

    def spawn_server
      server = TCPServer.new(config.host, config.port)
      srvlock.synchronize do
        self.server_spawned = true
      end

      loop do
        Thread.start(server.accept) do |sock|
          begin
            data   = JSON.load(sock.gets.chomp)
            action = data['action']
            q      = data['queue'].to_sym if data['queue']

            Komodor.write(:info, "connected :: #{data.inspect}")

            case action
            when 'quit', 'exit'
              FileUtils.rm config.pidfile if File.exists?(config.pidfile)
              exit 0
            when 'protect'
              Herd.protect!
              sock.puts YAML.dump(response: "ok", running: Herd.running)
            when 'get'
              sock.puts YAML.dump(collection[q])
            when 'remove'
              queue = collection[q]
              collection.delete(q) if queue
              sock.puts YAML.dump(response(collection))
            when 'set'
              collection[q] = Herd[q] unless collection[q]
              sock.puts YAML.dump(collection[q])
            else
              args   = data['args']
              queue  = collection[q]
              resp = queue.send(action, *args)

              sock.puts YAML.dump(response: resp)
            end
          rescue => e
            Komodor.write(:error, "[ERRROR] #{[e.class, e.message].join(" ~> ")}")
          ensure
            sock.close
          end
        end
      end
    end

    def stop!
      return false unless running?

      send_data(action: 'quit')
    end

    def running?
      return false unless File.exists?(config.pidfile)
      Process.kill(0, File.read(config.pidfile).chomp.to_i)
      true
    rescue Errno::ESRCH
      FileUtils.rm config.pidfile
      false
    end

    private

    def build_opts(opts)
      opts[:blk] = opts[:blk].to_source if opts[:blk]
      JSON.dump(opts)
    end

    def send_data(opts)
      socket = TCPSocket.new(config.host, config.port)
      socket.puts(build_opts(opts))
      YAML.load(socket.read)
    ensure
      socket.close
    end

    def collection
      @collection ||= {}
    end

    def method_missing(meth, *args, &blk)
      send_data({
        action: meth,
        queue: args.shift,
        args: args,
        blk: blk
      })
    end
  end

  # Default config
  config do |conf|
    conf.pidfile = "/tmp/komodor.pid"
    conf.logger  = nil
    conf.host    = "0"
    conf.port    = 60001
  end
end

