require 'spec_helper'

FooError = Class.new(StandardError)

describe Cachext, "backups" do
  let(:cache) { Cachext.config.cache }
  let(:error_logger) { Cachext.config.error_logger }

  describe "fetch" do
    let(:key) { [:test, 1] }
    let(:backup_key) { Cachext.backup_key key }

    before do
      cache.delete key
      cache.delete backup_key
    end

    context "no cache" do
      it "returns the value of the block" do
        expect(Cachext.fetch(key, expires_in: 1.minute) { "abc" }).to eq("abc")
      end

      it "writes the value of the block to the cache" do
        Cachext.fetch(key, expires_in: 1.minute) { "abc" }
        expect(cache.read(key)).to eq("abc")
      end

      it "writes the value of the block to the backup" do
        Cachext.fetch(key, expires_in: 1.minute) { "abc" }
        expect(cache.read(backup_key)).to eq("abc")
      end

      it "only executes the block once" do
        obj = double("Thing")
        allow(obj).to receive(:foo).once.and_return("bar")
        Cachext.fetch(key, expires_in: 1.minute) { obj.foo }
      end

      context "error occurs for an error that is specified to be caught" do
        let(:error) { FooError.new }

        it "logs the error" do
          expect(error_logger).to receive(:error).with(error)
          Cachext.fetch(key, expires_in: 1.minute, errors: [FooError]) { raise error }
        end

        it "returns the default value" do
          expect(Cachext.fetch(key, expires_in: 1.minute, errors: [FooError], default: "default") { raise error }).
            to eq("default")
        end

        it "will call the default if its a proc" do
          expect(Cachext.fetch(key, expires_in: 1.minute, errors: [FooError], default: ->(k) { "default#{k.length}" }) { raise error }).
            to eq("default2")
        end
      end
    end

    context "recent cache" do
      before do
        cache.write key, "foo"
      end

      it "uses the value from the cache" do
        expect(Cachext.fetch(key, expires_in: 1.minute) { "abc" }).to eq("foo")
      end

      it "does not execute the block" do
        obj = double("Thing")
        expect(obj).to_not receive(:foo)
        Cachext.fetch(key, expires_in: 1.minute) { obj.foo }
      end

      context "error occurs for an error that is specified to be caught" do
        let(:error) { FooError.new }

        it "doesn't log the error since it wasn't raised" do
          expect(error_logger).to_not receive(:error).with(error)
          Cachext.fetch(key, expires_in: 1.minute, errors: [FooError]) { raise error }
        end

        it "returns the cached value" do
          expect(Cachext.fetch(key, expires_in: 1.minute, errors: [FooError], default: "default") { raise error }).
            to eq("foo")
        end
      end
    end

    context "backup exists" do
      before do
        cache.write backup_key, "foo"
      end

      it "returns the value of the block" do
        expect(Cachext.fetch(key, expires_in: 1.minute) { "abc" }).to eq("abc")
      end

      it "writes the value of the block to the cache" do
        Cachext.fetch(key, expires_in: 1.minute) { "abc" }
        expect(cache.read(key)).to eq("abc")
      end

      it "writes the value of the block to the backup" do
        Cachext.fetch(key, expires_in: 1.minute) { "abc" }
        expect(cache.read(backup_key)).to eq("abc")
      end

      it "only executes the block once" do
        obj = double("Thing")
        allow(obj).to receive(:foo).once.and_return("bar")
        Cachext.fetch(key, expires_in: 1.minute) { obj.foo }
      end

      context "error occurs for an error that is specified to be caught" do
        let(:error) { FooError.new }

        it "logs the error" do
          expect(error_logger).to receive(:error).with(error)
          Cachext.fetch(key, expires_in: 1.minute, errors: [FooError]) { raise error }
        end

        it "returns the backup value" do
          expect(Cachext.fetch(key, expires_in: 1.minute, errors: [FooError], default: "default") { raise error }).
            to eq("foo")
        end
      end

      context "server raises a NotFound error" do
        let(:error) { Faraday::Error::ResourceNotFound.new('the url') }

        it "deletes the backup" do
          begin
            Cachext.fetch(key, expires_in: 1.minute) { raise error }
          rescue Faraday::Error::ResourceNotFound
          end
          expect(cache.read(backup_key)).to be_nil
        end

        it "reraises the error " do
          expect { Cachext.fetch(key, expires_in: 1.minute) { raise error } }.
            to raise_error(error)
        end
      end
    end
  end
end
