require 'spec_helper'
require 'set'

class Bar
  AlreadyClickedError = Class.new(StandardError)

  def initialize(id)
    @id = id
    @count = 0
    @mutex = Mutex.new
  end

  def key
    [:bar, @id]
  end

  def unsafe_click
    @mutex.synchronize do
      raise AlreadyClickedError, "somebody already clicking Bar #{@id}" if $clicking.include?(@id)
      $clicking << @id
    end
    sleep 0.01
    @count += 1
    $clicking.delete @id
    @count
  end

  def click
    Cachext.fetch key do
      unsafe_click
    end
  end

  def slow_click
    Cachext.fetch key do
      sleep 1
    end
  end
end

class Sleeper
  def initialize
    @id = SecureRandom.hex
  end

  def key
    [:sleeper, @id]
  end

  def poke
    Cachext.fetch(key, heartbeat_expires: 0.5) do
      sleep 3
    end
  end
end

describe Cachext::Features::Lock do
  before do
    $clicking = Set.new
  end

  let(:bar) { Bar.new(rand.to_s) }

  it "will raise an error without locking" do
    a = Thread.new do
      bar.unsafe_click
    end
    b = Thread.new do
      bar.unsafe_click
    end
    expect do
      a.join
      b.join
    end.to raise_error(Bar::AlreadyClickedError)
  end

  it "will raise an error without locking when using a threadpool" do
    pool = Thread.pool 2
    Thread::Pool.abort_on_exception = true
    expect do
      pool.process do
        bar.unsafe_click
      end
      pool.process do
        bar.unsafe_click
      end
      pool.shutdown
    end.to raise_error(Bar::AlreadyClickedError)
  end

  it "doesn't blow up if you lock it (simple thread)" do
    a = Thread.new do
      expect(bar.click).to eq(1)
    end
    b = Thread.new do
      expect(bar.click).to eq(1)
    end
    a.join
    b.join
  end

  it "doesn't blow up if you lock it (pre-existing thread pool, more reliable)" do
    pool = Thread.pool 2
    Thread::Pool.abort_on_exception = true
    pool.process do
      expect(bar.click).to eq(1)
    end
    pool.process do
      expect(bar.click).to eq(1)
    end
    pool.shutdown
  end

  it "can set a wait time" do
    pool = Thread.pool 2
    Thread::Pool.abort_on_exception = true
    begin
      old_max = Cachext.config.max_lock_wait
      Cachext.config.max_lock_wait = 0.2
      expect(Cachext.config.error_logger).
        to receive(:call).with(kind_of(Cachext::Features::Lock::TimeoutWaitingForLock))

      pool.process do
        bar.slow_click
      end
      pool.process do
        bar.slow_click
      end
      pool.shutdown
    ensure
      Cachext.config.max_lock_wait = old_max
    end
  end

  describe "lock wait timeout" do
    before do
      @old_max = Cachext.config.max_lock_wait
      Cachext.config.max_lock_wait = 0.2
      Cachext.config.raise_errors = true
    end

    after do
      Cachext.config.max_lock_wait = @old_max
    end

    it "raises a timeout if the lock doesn't get released in time" do
      mutex = Mutex.new
      resource = ConditionVariable.new
      Thread.new do
        Cachext.fetch(:foo, cache: false) {
          mutex.synchronize { resource.signal }
          sleep 2
        }
      end

      mutex.synchronize { resource.wait(mutex) }

      expect { Cachext.fetch(:foo, cache: false, reraise_errors: true) { :bar } }.
        to raise_error(Cachext::Features::Lock::TimeoutWaitingForLock)
    end

    it "does not raise a timeout if it has to wait but not too long" do
      mutex = Mutex.new
      resource = ConditionVariable.new
      thread = Thread.new do
        Cachext.fetch(:foo, cache: false) {
          mutex.synchronize { resource.signal }
          sleep 0.1
          :derp
        }
      end

      mutex.synchronize { resource.wait(mutex) }

      expect(Cachext.fetch(:foo, cache: false, reraise_errors: true) { :bar }).
        to eq(:bar)
      expect(thread.value).to eq(:derp)
    end
  end

  context "process dies" do
    let!(:sleeper) { Sleeper.new }
    let(:key) { Cachext::Key.new(sleeper.key) }

    it "unlocks" do
      child = nil
      begin
        child = Process.fork do
          Cachext.config.cache = ActiveSupport::Cache::MemCacheStore.new
          Cachext.config.redis = Redis.new
          sleeper.poke
        end
        sleep 0.1
        expect(key).to be_locked  # the other process has it
        Process.kill 'KILL', child
        expect(key).to be_locked  # the other (dead) process still has it
        sleep 0.5
        expect(key).to_not be_locked # but now it should be cleared because no heartbeat
      ensure
        Process.kill('KILL', child) rescue Errno::ESRCH
      end
    end

    it "pays attention to heartbeats" do
      child = nil
      begin
        child = Process.fork do
          Cachext.config.cache = ActiveSupport::Cache::MemCacheStore.new
          Cachext.config.redis = Redis.new
          sleeper.poke
        end
        sleep 0.1
        expect(key).to be_locked # the other process has it
        sleep 0.5
        expect(key).to be_locked # the other process still has it
        sleep 0.5
        expect(key).to be_locked # the other process still has it
        sleep 0.5
        expect(key).to be_locked # the other process still has it
      ensure
        Process.kill('TERM', child) rescue Errno::ESRCH
      end
    end
  end
end
