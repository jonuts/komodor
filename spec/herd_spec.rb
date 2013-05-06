require 'spec_helper'

class GoodHerd < Komodor::Herd
  key :good
  cmd :foo
  on(:start) do
    while File.exists?(foo) do
      sleep 0.1
    end
    complete
  end
  on(:stop) do
    self.message = "goodbye, cruel world"
  end
end

class ErrorHerd < Komodor::Herd
  key :bad
  on(:start) {lolerror}
end

describe Komodor::Herd do
  describe "setup" do
    context "invalid setup" do
      before do
        class FooHerd < Komodor::Herd; end
      end

      it "throws an error if no key is provided" do
        expect { FooHerd.start }.to raise_error(Komodor::Herd::KeyRequired)
      end

      it "throws an error if no startup block is provided" do
        FooHerd.key(:foo)
        expect { FooHerd.start }.to raise_error(Komodor::Herd::NoStartBlock)
      end
    end

    context "valid setup" do
      before :all do
        @srv = Thread.new {Komodor.start!}
        sleep 0.3
      end

      after :all do
        @srv.kill
      end

      describe "queue" do
        before :all do
          @condition = "/tmp/__herdtest"
          FileUtils.touch(@condition)
          Komodor.add(:good, @condition)
        end

        before :each do
          @runners = Komodor.runners(:good)[:response]
        end

        it "starts a new runner" do
          @runners.should have(1).thing
        end

        specify "runner should be alive" do
          @runners.first.status.should eql(:running)
        end

        it "should stop execution when condition is no longer met" do
          FileUtils.rm(@condition)
          sleep 0.2
          Komodor.runners(:good)[:response].last.status.should eql(:done)
        end
      end

      describe "stopping" do
        before :all do
          @condition = "/tmp/__herdtest"
          FileUtils.touch(@condition)
          Komodor.add(:good, @condition)
          sleep 0.2
          Komodor.stop(:good)
          @runner = Komodor.runners(:good)[:response].last
        end

        it "marks runners as complete" do
          @runner.status.should eql(:done)
        end

        it "runs the stop hook" do
          @runner.message.should eql("goodbye, cruel world")
        end

        it "kills the worker thread" do
          GoodHerd.instance_variable_get(:@worker).should_not be_alive
        end
      end
    end
  end

  describe "errors" do
    before :all do
      @srv = Thread.new {Komodor.start!}
      sleep 0.3
      Komodor.add(:bad, true)
      @runners = Komodor.runners(:bad)[:response]
    end

    after :all do
      @srv.kill
    end

    specify "status is set to error" do
      @runners.first.status.should eql(:error)
    end

    specify "message is set" do
      @runners.first.message.should match(/^NameError.+lolerror/)
    end
  end
end
