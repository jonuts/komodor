module Komodor
  class Herd
    class KeyRequired < StandardError; end
    class NoStartBlock < StandardError; end

    class << self
      def [](key)
        collection.find {|c| c.key == key}
      end

      def where(clause)
        runners.select do |runner|
          runner.instance_eval(&clause)
        end
      end

      def running
        collection.select(&:started?)
      end

      def protect!
        collection.each do |herd|
          herd.start(&herd.hooks[:start])
        end
      end

      def key(name=nil)
        return @__key__ unless name
        @__key__ = name
      end

      def started?
        !!@started
      end

      def action(&blk)
        return @__action__ unless block_given?
        @__action__ = blk
      end

      def hooks
        @hooks ||= {}
      end

      def queue
        @queue ||= Queue.new
      end

      def start(&runblk)
        return if started?
        raise KeyRequired, "your herd requires a key to start" unless key
        raise NoStartBlock, "no start block provided" unless block_given?
        @started = true
        Komodor << key

        @worker = Thread.new do
          loop do
            Thread.start(queue.shift) do |cmd|
              runner = new(cmd)
              begin
                runner.instance_eval(&runblk)
              rescue => e
                runner.status = :error
                runner.message = [e.class, e.message].join(" ~> ")
              end
            end
          end
        end
      end

      def stop
        return unless hooks[:stop]
        runners.select {|r| r.status == :running}.each do |runner|
          runner.complete
          runner.instance_eval(&hooks[:stop])
        end
        @worker.kill
        runners
      end

      def add(cmd, &callback)
        queue << {cmd: cmd, callback: callback}
        self
      end

      def runners(*opts)
        @runners ||= []
      end

      private

      def cmd(name)
        define_method(name) { args[:cmd] }
      end

      def on(meth, &blk)
        hooks[meth] = blk
      end

      def inherited(klass)
        collection << klass
      end

      def collection
        @__collection__ ||= []
      end
    end

    def initialize(args)
      @status = :running
      @args = args
      self.class.runners << self
    end

    attr_reader :args
    attr_accessor :status, :message

    def complete(msg=nil)
      @status = :done
      @message = msg || "done"
      Komodor.write :debug, "completing #{inspect}"
    end
  end
end
