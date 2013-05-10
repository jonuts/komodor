module Komodor
  class Runner
    def initialize(cmdname=nil)
      define_singleton_method(cmdname) { args[:cmd] } if cmdname
      @status = :waiting
    end

    attr_reader :args
    attr_accessor :status, :message, :worker_thread

    def run!(args, &blk)
      self.status = :running
      @args = args
      begin
        instance_eval(&blk)
      rescue => e
        self.status = :error
        self.message = [e.class, e.message].join(" ~> ")
      end
    end

    def complete(msg=nil)
      self.status = :done
      self.message = msg || "done"
      worker_thread.kill
    end

    def to_yaml_properties
      [:@status, :@message, :@args]
    end

    def every(seconds)
      loop do
        next_run = Time.now + seconds
        yield
        stime = next_run - Time.now
        sleep stime if stime > 0
      end
    end
  end
end
