require "spec_helper"

describe Cachext, "caching" do
  let(:cache) { Cachext.config.cache }

  before do
    Cachext.flush
  end

  let(:key) { Cachext::Key.new [:test, 1] }

  it "returns the value of the block" do
    expect(Cachext.fetch(key) { "abc" }).to eq("abc")
  end

  it "writes the value of the block to the cache" do
    Cachext.fetch(key) { "abc" }
    expect(key.read).to eq("abc")
  end

  it "only executes the block once" do
    obj = double("Thing")
    allow(obj).to receive(:foo).once.and_return("bar")
    Cachext.fetch(key) { obj.foo }
    Cachext.fetch(key) { obj.foo }
  end

  it "can be expired" do
    expect(Cachext.fetch(key, expires_in: 1) { "abc" }).to eq("abc")
    expect(Cachext.fetch(key, expires_in: 1) { "foo" }).to eq("abc")
    sleep 1.1
    expect(Cachext.fetch(key, expires_in: 1) { "bar" }).to eq("bar")
  end

  it "can be cleared" do
    expect(Cachext.fetch(key) { "abc" }).to eq("abc")
    Cachext.clear key
    expect(Cachext.fetch(key) { "foo" }).to eq("foo")
  end
end
