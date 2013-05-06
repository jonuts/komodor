require 'spec_helper'

describe Komodor::Herd do
  describe "setup" do
    context "invalid setup" do
      before do
        class FooHerd < Komodor::Herd; end
      end

      after do
        Komodor::Herd.send(:collection).clear
        Object.send(:remove_const, :FooHerd)
      end

      it "throws an error if no key is provided" do
        expect { Komodor::Herd.protect! }.to raise_error(Komodor::Herd::KeyRequired)
      end

      it "throws an error if no startup block is provided" do
        FooHerd.key(:foo)
        expect { Komodor::Herd.protect! }.to raise_error(Komodor::Herd::NoStartBlock)
      end
    end

    context "valid setup" do
      before :all do
        class FooHerd < Komodor::Herd
          key :foo
          cmd :foo

          on(:start) do
            while File.exists?(foo)
              sleep 0.1
            end
            complete
          end
        end
        @srv = Thread.new {Komodor.start!}
        sleep 0.3
      end

      after :all do
        Komodor::Herd.send(:collection).clear
        Komodor.remove(:foo)
        Object.send(:remove_const, :FooHerd)
        @srv.kill
      end

      describe "queue" do
        before :all do
          @condition = "/tmp/__herdtest"
          FileUtils.touch(@condition)
          Komodor.add(:foo, @condition)
        end

        before :each do
          @runners = Komodor.runners(:foo)[:response]
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
          Komodor.runners(:foo)[:response].first.status.should eql(:done)
        end
      end
    end
  end

  describe "errors" do
    before :all do
      class FooHerd < Komodor::Herd
        key :foo
        on(:start) {lolerror}
      end
      @srv = Thread.new {Komodor.start!}
      sleep 0.3
      Komodor.add(:foo, true)
      @runners = Komodor.runners(:foo)[:response]
    end

    after :all do
      Komodor::Herd.send(:collection).clear
      Komodor.remove(:foo)
      Object.send(:remove_const, :FooHerd)
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
