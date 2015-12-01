require 'spec_helper'

FooError = Class.new(StandardError)

describe Cachext::Features::Default do
  let(:cache) { Cachext.config.cache }
  let(:error_logger) { Cachext.config.error_logger }

  before do
    Cachext.flush
  end

  describe "#handle_error" do
    let(:key) { Cachext::Key.new([:test, 1]) }
    let(:backup_key) { key.backup }

    context "no cache" do
      context "error occurs for a default error type" do
        let(:error) { Faraday::Error::ConnectionFailed.new double }

        it "returns the default value" do
          expect(Cachext.fetch(key, default: "default") { raise error }).
            to eq("default")
        end

        it "will call the default if its a proc" do
          expect(Cachext.fetch(key, default: ->(k) { "default#{k.raw.length}" }) { raise error }).
            to eq("default2")
        end
      end

      context "error occurs for an error that is specified to be caught" do
        let(:error) { FooError.new }

        it "returns the default value" do
          expect(Cachext.fetch(key, errors: [FooError], default: "default") { raise error }).
            to eq("default")
        end

        it "will call the default if its a proc" do
          expect(Cachext.fetch(key, errors: [FooError], default: ->(k) { "default#{k.raw.length}" }) { raise error }).
            to eq("default2")
        end
      end
    end
  end

  describe "#handle_not_found" do
    let(:key) { Cachext::Key.new([:test, 1]) }
    let(:backup_key) { key.backup }

    context "the resource is not found" do
      let(:error) { Faraday::Error::ResourceNotFound.new double }

      it "returns the default value" do
        expect(Cachext.fetch(key, reraise_errors: false, default: "default") { raise error }).
          to eq("default")
      end

      it "will call the default if its a proc" do
        expect(Cachext.fetch(key, reraise_errors: false, default: ->(k) { "default#{k.raw.length}" }) { raise error }).
          to eq("default2")
      end
    end
  end
end

