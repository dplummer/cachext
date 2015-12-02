require "spec_helper"

Record = Struct.new :id

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
end
