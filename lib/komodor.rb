require "socket"
require "yaml"
require "json"
require "thread"
require "ostruct"
require "bundler/setup"
Bundler.require :default
require_relative "komodor/server"
require_relative "komodor/request"
require_relative "komodor/herd"
require_relative "komodor/runner"

module Komodor
  class << self
    attr_accessor :server_spawned, :server, :server_thread

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
      spawn_server
      sleep 0.2 until server_spawned?
      send_data(action: 'protect')
      server_thread.join
    end

    def server_spawned?
      !!server_spawned
    end

    def spawn_server
      self.server         = Server.new(config.host, config.port)
      self.server_thread  = Thread.new {server.run!}
      self.server_spawned = true
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

