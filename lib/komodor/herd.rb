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
          raise KeyRequired, "your herd requires a key to start" unless herd.key
          raise NoStartBlock, "no startup block provided" unless herd.hooks[:start]
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
        @started = true
        Komodor << key

        @worker = Thread.new do
          loop do
            Thread.start(queue.shift) do |cmd|
              runner = new(cmd)
              runner.instance_eval(&runblk)
            end
          end
        end
      end

      def add(cmd, &callback)
        queue << {cmd: cmd, callback: callback}
        self
      end

      def runners
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

    attr_reader :status, :args

    def complete
      @status = :done
      Komodor.write "completing #{inspect}"
    end
  end
end
