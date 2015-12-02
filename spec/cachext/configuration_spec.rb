require "spec_helper"

describe Cachext::Configuration do
  describe ".setup" do
    let!(:redis) { Cachext.config.redis }

    it "yields the config to the provided block" do
      expect { |b| Cachext::Configuration.setup(&b) rescue Cachext::Configuration::MissingConfiguration }.to yield_with_args(Cachext::Configuration)
    end

    it "returns the new configuration" do
      config = nil
      retval = Cachext::Configuration.setup { |conf|
        conf.cache = double("Cache")
        conf.redis = redis
        config = conf
      }
      expect(retval).to eq(config)
    end

    it "raises if no block is passed" do
      expect { Cachext::Configuration.setup }.to raise_error(LocalJumpError)
    end

    it "requires the cache to be setup" do
      expect { Cachext::Configuration.setup { |config| config.redis = redis } }.
        to raise_error(Cachext::Configuration::MissingConfiguration, "Must configure the config.cache. Try config.cache = Rails.cache")
    end

    it "requires the redis to be setup" do
      expect { Cachext::Configuration.setup { |config| config.cache = double("Cache") } }.
        to raise_error(Cachext::Configuration::MissingConfiguration, "Must configure the config.redis. Try config.redis = Redis.current")
    end
  end
end
