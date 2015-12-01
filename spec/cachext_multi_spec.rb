require "spec_helper"

Record = Struct.new :id

class Multirepo
  def self.where(params)
    params.fetch(:id).reject {|id| id == 404}.map { |id| Record.new id }
  end
end

describe Cachext do
  describe ".multi" do
    it "delegates to Multi" do
      multi = double("Cachext::Multi")
      expect(multi).to receive(:fetch).with([1,2,3])
      expect(Cachext::Multi).to receive(:new).
        with(Cachext.config, Multirepo, expires_in: 20).
        and_return(multi)
      Cachext.multi Multirepo, [1,2,3], expires_in: 20
    end
  end
end

describe Cachext::Multi do
  let(:config) { Cachext.config }
  subject { Cachext::Multi.new config, Multirepo, expires_in: 0.1 }

  before do
    Cachext.flush
  end

  it "looks up records from the repo" do
    expect(Multirepo).to receive(:where).with(id: [1,2,3], per_page: 3).and_call_original
    subject.fetch [1,2,3]
  end

  it "records the results in the cache" do
    expect(Multirepo).to receive(:where).with(id: [1,2,3], per_page: 3).once.and_call_original
    subject.fetch [1,2,3]
    subject.fetch [1,2,3]
  end

  it "returns the found records" do
    expect(subject.fetch [1,2,3]).to eq([Record.new(1), Record.new(2), Record.new(3)])
  end

  it "caches records independently" do
    expect(Multirepo).to receive(:where).with(id: [1,2], per_page: 2).once.and_call_original
    expect(Multirepo).to receive(:where).with(id: [3], per_page: 1).once.and_call_original
    subject.fetch [1,2]
    subject.fetch [2,3]
  end

  it "returns missing record objects when the object is not returned" do
    expect(subject.fetch [1,404]).to eq([Record.new(1), Cachext::MissingRecord.new(404)])
  end

  it "expires the cache" do
    expect(Multirepo).to receive(:where).with(id: [1,2,3], per_page: 3).twice.and_call_original
    subject.fetch [1,2,3]
    sleep 0.3
    subject.fetch [1,2,3]
  end

  context "a backup exists" do
    let(:backup_record) { Record.new 500 }

    before do
      config.cache.write [:backup_cache, "Multirepo", 500], backup_record
    end

    context "an error is raised" do
      let(:error) { Faraday::Error::ConnectionFailed.new(double) }

      it "uses the backup when the repo raises an error" do
        allow(Multirepo).to receive(:where).and_raise(error)

        expect(subject.fetch [500]).to eq([backup_record])
      end
    end
  end

  context "no backup exists" do
    context "an error is raised" do
      let(:error) { Faraday::Error::ConnectionFailed.new(double) }

      it "uses the backup when the repo raises an error" do
        allow(Multirepo).to receive(:where).and_raise(error)

        expect(subject.fetch [500]).to eq([Cachext::MissingRecord.new(500)])
      end
    end
  end
end
