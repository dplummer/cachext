module Cachext
  MissingRecord = Struct.new(:id)
  class MissingRecord
    def missing?
      true
    end

    def present?
      false
    end
  end
end
