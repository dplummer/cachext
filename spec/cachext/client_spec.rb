require "spec_helper"

FooError = Class.new(StandardError)

describe Cachext, "caching" do
  let(:cache) { Cachext.config.cache }

  let(:config) { Cachext::Configuration.new }
  subject { Cachext::Client.new config }

  let(:key) { Cachext::Key.new [:test, 1] }

  it "returns the value of the block" do
    expect(subject.fetch(key) { "abc" }).to eq("abc")
  end

  it "writes the value of the block to the cache" do
    subject.fetch(key) { "abc" }
    expect(key.read).to eq("abc")
  end

  it "only executes the block once" do
    obj = double("Thing")
    allow(obj).to receive(:foo).once.and_return("bar")
    subject.fetch(key) { obj.foo }
    subject.fetch(key) { obj.foo }
  end

  it "can be expired" do
    expect(subject.fetch(key, expires_in: 1) { "abc" }).to eq("abc")
    expect(subject.fetch(key, expires_in: 1) { "foo" }).to eq("abc")
    sleep 1.1
    expect(subject.fetch(key, expires_in: 1) { "bar" }).to eq("bar")
  end

  it "can be cleared" do
    expect(subject.fetch(key) { "abc" }).to eq("abc")
    Cachext.clear key
    expect(subject.fetch(key) { "foo" }).to eq("foo")
  end

  describe "not logging errors" do
    before do
      config.raise_errors = true
      config.error_logger = nil
    end

    context "options set to reraise_errors" do
      let(:error) { FooError.new }

      it "reraises the error" do
        expect { subject.fetch(key, errors: [FooError]) { raise error } }.
          to raise_error(error)
      end
    end
  end
end
