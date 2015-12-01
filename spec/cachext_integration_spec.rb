require "spec_helper"

describe Cachext, "integration" do
  let(:cache)         { Cachext.config.cache }
  let(:key)           { Cachext::Key.new [:test, 1] }
  let(:backup_key)    { key.backup }
  let(:max_lock_wait) { Cachext.config.max_lock_wait }

  context "backup exists, service times out" do
    before do
      Cachext.flush
      @old_max = Cachext.config.max_lock_wait
      Cachext.config.max_lock_wait = 0.2
      cache.write backup_key, "old value"
    end

    after do
      Cachext.config.max_lock_wait = @old_max
    end

    it "returns the backup value" do
      sleeper = Thread.new do
        Cachext.fetch(key) { sleep }
      end
      sleep 0.1
      Thread.new do
        expect(Cachext.fetch(key) { sleep max_lock_wait + 1; "new" }).to eq("old value")
      end.join

      sleeper.kill
    end
  end
end
