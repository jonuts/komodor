lib = File.expand_path("..", __FILE__)
$:.push(lib) unless $:.include?(lib)

require "socket"
require "yaml"
require "json"
require "thread"
require "bundler/setup"
Bundler.require :default
require "komodor/herd"

module Komodor
  PIDFILE = "/tmp/komodor.pid"
  HOST = '0'
  PORT = 60001

  class << self
    attr_accessor :server_spawned

    def loglock
      @loglock ||= Mutex.new
    end

    def srvlock
      @srvlock ||= Mutex.new
    end

    def write(stuff)
      loglock.synchronize do
        tstamp = Time.now.strftime("[%D %T]")
        File.open("/tmp/gah.log", "a+") {|f| f.puts [tstamp, stuff].join(" :: ")}
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
        puts "[komodor] running. pid #{File.read(PIDFILE)}"
        exit 0
      end

      pid = Process.fork do
        $0 = "[komodor]"
        start!
      end

      File.open(PIDFILE, 'w') {|f| f.puts pid}
      puts "[komodor] running. pid #{File.read(PIDFILE)}"
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
      server = TCPServer.new(HOST, PORT)
      srvlock.synchronize do
        self.server_spawned = true
      end

      loop do
        Thread.start(server.accept) do |sock|
          begin
            data   = JSON.load(sock.gets.chomp)
            action = data['action']
            q      = data['queue'].to_sym if data['queue']

            Komodor.write("connected :: #{data.inspect}")

            case action
            when 'quit', 'exit'
              FileUtils.rm PIDFILE if File.exists?(PIDFILE)
              exit 0
            when 'protect'
              Komodor.write "herding"
              Herd.protect!
              sock.puts YAML.dump(response: "ok", running: Herd.running)
            when 'get'
              sock.puts YAML.dump(collection[q])
            when 'remove'
              queue = collection[q]
              collection.delete(q) if queue
              sock.puts YAML.dump(response(collection))
            when 'set'
              Komodor.write "setting"
              collection[q] = Herd[q] unless collection[q]
              sock.puts YAML.dump(collection[q])
            else
              args   = data['args']
              queue  = collection[q]
              resp = queue.send(action, *args)

              sock.puts YAML.dump(response: resp)
            end
          rescue => e
            Komodor.write("[ERRROR] #{[e.class, e.message].join(" ~> ")}")
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
      return false unless File.exists?(PIDFILE)
      Process.kill(0, File.read(PIDFILE).chomp.to_i)
      true
    rescue Errno::ESRCH
      FileUtils.rm PIDFILE
      false
    end

    private

    def build_opts(opts)
      opts[:blk] = opts[:blk].to_source if opts[:blk]
      JSON.dump(opts)
    end

    def send_data(opts)
      socket = TCPSocket.new(HOST, PORT)
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
end

