require "spec_helper"

describe Cachext::Features::CircuitBreaker do
  before do
    Cachext.config.failure_threshold = 2
    Cachext.config.breaker_timeout = 60
  end

  class FailsSometimes
    attr_reader :pattern, :index

    BoomError = Class.new(StandardError)

    def initialize(pattern)
      @pattern = pattern
      @index = 0
    end

    def expensive_call
      answer = pattern[index] || pattern.last
      @index += 1
      case answer
      when :boom
        raise BoomError.new
      else
        answer
      end
    end

    def set_pattern(pattern)
      @pattern = pattern
    end
  end

  describe "tripping the breaker" do
    let(:service) { FailsSometimes.new([1,2,:boom]) }

    it "trips the circuit" do
      10.times do
        Cachext.fetch(:foo, cache: false, errors: [FailsSometimes::BoomError]) { service.expensive_call }
      end
      expect(service.index).to eq(4)
    end

    it "returns the backup immediately once tripped" do
      answers = 10.times.map do
        Cachext.fetch(:foo, cache: false, errors: [FailsSometimes::BoomError]) { service.expensive_call }
      end
      expect(answers).to eq([1,2,2,2,2,2,2,2,2,2])
    end

    it "waits a bit before becoming half-open to see if its okay again" do
      10.times do
        Cachext.fetch(:foo, cache: false, errors: [FailsSometimes::BoomError]) { service.expensive_call }
      end
      Timecop.travel(Time.now + 61.seconds)
      10.times do
        Cachext.fetch(:foo, cache: false, errors: [FailsSometimes::BoomError]) { service.expensive_call }
      end

      expect(service.index).to eq(5)
    end

    it "closes the breaker if it gets better" do
      answers = 10.times.map do
        Cachext.fetch(:foo, cache: false, errors: [FailsSometimes::BoomError]) { service.expensive_call }
      end
      Timecop.travel(Time.now + 61.seconds)
      service.set_pattern([3])
      answers += 10.times.map do
        Cachext.fetch(:foo, cache: false, errors: [FailsSometimes::BoomError]) { service.expensive_call }
      end
      expect(service.index).to eq(14)

      expect(answers).to eq([1, *([2] * 9), *([3] * 10)])
    end

    it "resets the number of failures required to open circuit" do
      10.times do
        Cachext.fetch(:foo, cache: false, errors: [FailsSometimes::BoomError]) { service.expensive_call }
      end
      Timecop.travel(Time.now + 61.seconds)
      service.set_pattern([3])
      10.times do
        Cachext.fetch(:foo, cache: false, errors: [FailsSometimes::BoomError]) { service.expensive_call }
      end
      service.set_pattern([4,:boom])
      10.times do
        Cachext.fetch(:foo, cache: false, errors: [FailsSometimes::BoomError]) { service.expensive_call }
      end

      expect(service.index).to eq(16)
    end

    it "syncs the circuit breaker between processes" do
      STDOUT.sync = true
      Process.fork do
        Cachext.forked!
        10.times do
          Cachext.fetch(:foo2, cache: false, errors: [FailsSometimes::BoomError]) { service.expensive_call }
        end
      end
      Process.wait

      expect(Cachext.fetch(:foo2, cache: false, errors: [FailsSometimes::BoomError]) { service.expensive_call }).
        to eq(2) # backup value
    end
  end
end
