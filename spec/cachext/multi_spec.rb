require "spec_helper"

Record = Struct.new :id

require 'set'
$multibar_clicking = Set.new
class MultiBar
  AlreadyClickedError = Class.new(StandardError)

  def initialize
    @name = rand
    @ids = []
  end

  def key_base
    [:multi_bar]
  end

  def unsafe_click(ids)
    Thread.exclusive do
      raise AlreadyClickedError, "somebody already multibar_clicking Bar #{@name}" if $multibar_clicking.include?(@name)
      $multibar_clicking << @name
    end
    sleep 0.01
    @ids += ids
    $multibar_clicking.delete @name
    @ids.map {|id| Record.new id}
  end

  def click(ids)
    Cachext.multi key_base, ids do |uncached_ids|
      unsafe_click uncached_ids
    end
  end

  def slow_click(ids)
    Cachext.multi key_base, ids do |uncached_ids|
      sleep 1
      uncached_ids.map {|id| Record.new id}
    end
  end
end

describe Cachext do
  describe ".multi" do
    it "delegates to Multi" do
      expect(Cachext::Multi).to receive(:new).
        with(Cachext.config, ["Multirepo"], expires_in: 20).
        and_call_original

      expect(Cachext.multi(["Multirepo"], [1,2,3], expires_in: 20) { |ids|
        ids.inject({}) { |acc,id| acc.merge(id => Record.new(id)) }
      }).to eq(1 => Record.new(1), 2 => Record.new(2), 3 => Record.new(3))
    end
  end
end

describe Cachext::Multi do
  let(:config) { Cachext.config }
  let(:key_base) { ["Multirepo"] }
  subject { Cachext::Multi.new config, key_base, expires_in: 0.1 }

  before do
    Cachext.flush
  end

  it "returns the found records" do
    expect(subject.fetch [1,2,3] { |ids|
      ids.inject({}) { |acc,id| acc.merge(id => Record.new(id)) }
    }).to eq({ 1 => Record.new(1), 2 => Record.new(2), 3 => Record.new(3) })
  end

  it "converts a block that returns an array to a hash by their id" do
    expect(subject.fetch [1,2,3] { |ids|
      ids.map { |id| Record.new id }
    }).to eq({ 1 => Record.new(1), 2 => Record.new(2), 3 => Record.new(3) })
  end

  it "records the results in the cache" do
    subject.fetch [1,2,3] do |ids|
      ids.inject({}) { |acc,id| acc.merge(id => Record.new(id)) }
    end

    subject.fetch [1,2,3] do |ids|
      raise "all the values should be cached"
    end
  end

  it "caches records independently" do
    subject.fetch [1,2] do |ids|
      expect(ids).to eq([1,2])
      ids.inject({}) { |acc,id| acc.merge(id => Record.new(id)) }
    end
    subject.fetch [2,3] do |ids|
      expect(ids).to eq([3])
      ids.inject({}) { |acc,id| acc.merge(id => Record.new(id)) }
    end
  end

  it "doesn't include the key if the record wasn't found" do
    expect(subject.fetch [1,404] { |ids|
      {1 => Record.new(1)}
    }).to eq(1 => Record.new(1))
  end

  it "expires the cache" do
    called = 0
    subject.fetch [1,2,3] do |ids|
      called += 1
      expect(ids).to eq([1,2,3])
      ids.inject({}) { |acc,id| acc.merge(id => Record.new(id)) }
    end
    sleep 0.3
    subject.fetch [1,2,3] do |ids|
      called += 1
      expect(ids).to eq([1,2,3])
      ids.inject({}) { |acc,id| acc.merge(id => Record.new(id)) }
    end
    expect(called).to eq(2)
  end

  context "a backup exists" do
    let(:backup_record) { Record.new 500 }
    let(:backup_key) { [:backup_cache, "Multirepo", 500] }

    before do
      config.cache.write backup_key, backup_record
    end

    context "an error is raised that we catch" do
      let(:error) { Faraday::Error::ConnectionFailed.new(double) }

      it "uses the backup when the repo raises an error" do
        expect(subject.fetch [500] { |ids| raise error }).to eq({ 500 => backup_record })
      end
    end

    context "no record is returned for an id we requested" do
      let(:backup_key) { [:backup_cache, "Multirepo", 404] }

      it "deletes the backup" do
        subject.fetch [1,404] { |ids| {1 => Record.new(1)} }
        expect(config.cache.read backup_key).to be_nil
      end

      it "does not return a record for the missing id" do
        expect(subject.fetch [1,404] { |ids|
          {1 => Record.new(1)}
        }).to eq(1 => Record.new(1))
      end
    end
  end

  context "no backup exists" do
    context "an error is raised that we catch" do
      let(:error) { Faraday::Error::ConnectionFailed.new(double) }

      it "doesn't include the id and returns nothing" do
        expect(subject.fetch [500] { |ids|
          raise error
        }).to eq({})
      end
    end
  end

  context "options specify returning an array of values" do
    subject { Cachext::Multi.new config, key_base, return_array: true }

    it "returns missing record objects when the object is not returned" do
      expect(subject.fetch [1,404] { |ids|
        {1 => Record.new(1)}
      }).to eq([Record.new(1), Cachext::MissingRecord.new(404)])
    end

    context "no backup exists" do
      context "an error is raised" do
        let(:error) { Faraday::Error::ConnectionFailed.new(double) }

        it "returns a missing record" do
          expect(subject.fetch [500] { |ids|
            raise error
          }).to eq([Cachext::MissingRecord.new(500)])
        end
      end
    end
  end

  describe "locking" do
    subject { MultiBar.new }

    it "will raise an error without locking" do
      a = Thread.new do
        subject.unsafe_click [1,2,3]
      end
      b = Thread.new do
        subject.unsafe_click [1,2,3]
      end
      expect do
        a.join
        b.join
      end.to raise_error(MultiBar::AlreadyClickedError)
    end

    it "will raise an error without locking when using a threadpool" do
      pool = Thread.pool 2
      Thread::Pool.abort_on_exception = true
      expect do
        pool.process do
          subject.unsafe_click [1,2,3]
        end
        pool.process do
          subject.unsafe_click [1,2,3]
        end
        pool.shutdown
      end.to raise_error(MultiBar::AlreadyClickedError)
    end

    it "doesn't blow up if you lock it (simple thread)" do
      a = Thread.new do
        expect(subject.click([1,2,3]).keys).to eq([1,2,3])
      end
      b = Thread.new do
        expect(subject.click([1,2,3]).keys).to eq([1,2,3])
      end
      a.join
      b.join
    end

    it "doesn't blow up if you lock it (pre-existing thread pool, more reliable)" do
      pool = Thread.pool 2
      Thread::Pool.abort_on_exception = true
      pool.process do
        expect(subject.click([1,2,3]).keys).to eq([1,2,3])
      end
      pool.process do
        expect(subject.click([1,2,3]).keys).to eq([1,2,3])
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
          to receive(:call).with(kind_of(Cachext::Features::Lock::TimeoutWaitingForLock)).
          twice

        pool.process do
          subject.slow_click [1,2,3]
        end
        pool.process do
          subject.slow_click [1,2,3]
        end
        pool.shutdown
      ensure
        Cachext.config.max_lock_wait = old_max
      end
    end

    context "process dies" do
      let(:key) { Cachext::Key.new([:sleeper, 1, 2, 3]) }

      it "unlocks" do
        child = nil
        begin
          child = fork do
            Cachext.config.cache = ActiveSupport::Cache::MemCacheStore.new
            Cachext.multi([:sleeper], [1,2,3], heartbeat_expires: 0.5) { sleep }
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
          child = fork do
            Cachext.config.cache = ActiveSupport::Cache::MemCacheStore.new
            Cachext.multi([:sleeper], [1,2,3], heartbeat_expires: 0.5) { sleep }
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
end
