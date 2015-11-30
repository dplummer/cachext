require 'spec_helper'

require 'set'
$clicking = Set.new
class Bar
  AlreadyClickedError = Class.new(StandardError)

  def initialize(id)
    @id = id
    @count = 0
  end

  def key
    [:bar, @id]
  end

  def unsafe_click
    Thread.exclusive do
      # puts "clicking bar #{@id} - #{$clicking.to_a} - #{$clicking.include?(@id)} - #{@id == $clicking.to_a[0]}"
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
      sleep 0.01
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
    Cachext.fetch(key, heartbeat_expires: 0.05) do
      sleep
    end
  end
end

describe Cachext, "locking" do
  before do
    Cachext.flush
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
      bar.click
    end
    b = Thread.new do
      bar.click
    end
    a.join
    b.join
  end

  it "doesn't blow up if you lock it (pre-existing thread pool, more reliable)" do
    pool = Thread.pool 2
    Thread::Pool.abort_on_exception = true
    pool.process do
      bar.click
    end
    pool.process do
      bar.click
    end
    pool.shutdown
  end

  it "can set a wait time" do
    pool = Thread.pool 2
    Thread::Pool.abort_on_exception = true
    begin
      old_max = Cachext.config.max_lock_wait
      Cachext.config.max_lock_wait = 0.2
      expect do
        pool.process do
          bar.slow_click
        end
        pool.process do
          bar.slow_click
        end
        pool.shutdown
      end.to raise_error(Cachext::Client::TimeoutWaitingForLock)
    ensure
      Cachext.config.max_lock_wait = old_max
    end
  end

  context "process dies" do
    it "unlocks" do
      child = nil
      begin
        sleeper = Sleeper.new
        child = fork do
          sleeper.poke
        end
        sleep 0.01
        expect(Cachext.locked? sleeper.key).to eq(true)  # the other process has it
        Process.kill 'KILL', child
        expect(Cachext.locked? sleeper.key).to eq(true)  # the other (dead) process still has it
        sleep 0.05
        expect(Cachext.locked? sleeper.key).to eq(false) # but now it should be cleared because no heartbeat
      ensure
        Process.kill('KILL', child) rescue Errno::ESRCH
      end
    end
  end

  it "pays attention to heartbeats" do
    child = nil
    begin
      sleeper = Sleeper.new
      child = fork do
        sleeper.poke
      end
      sleep 0.01
      expect(Cachext.locked? sleeper.key).to eq(true) # the other process has it
      sleep 0.05
      expect(Cachext.locked? sleeper.key).to eq(true) # the other process still has it
      sleep 0.05
      expect(Cachext.locked? sleeper.key).to eq(true) # the other process still has it
      sleep 0.05
      expect(Cachext.locked? sleeper.key).to eq(true) # the other process still has it
    ensure
      Process.kill('TERM', child) rescue Errno::ESRCH
    end
  end
end
