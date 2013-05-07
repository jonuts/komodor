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
            runner = Runner.new(cmd)
            runners << runner
            runner.worker_thread = Thread.start(queue.shift) do |cmd|
              runner.run!(cmd, &runblk)
            end
          end
        end
        runners
      end

      def stop
        runners(:running).each do |runner|
          runner.complete
          runner.instance_eval(&hooks[:stop]) if hooks[:stop]
        end
        @worker.kill
        runners
      end

      def add(cmd, &callback)
        queue << {cmd: cmd, callback: callback}
        self
      end

      def runners(*opts)
        return @runners ||= [] if opts.empty?
        status = opts.first
        @runners.select {|r| r.status.to_s == status.to_s}
      end

      private

      def cmd(name=nil)
        return @__cmd__ unless name
        @__cmd__ = name
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
  end
end
