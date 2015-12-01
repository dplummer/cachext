require "active_support/core_ext/module/delegation"

module Cachext
  class Multi
    delegate :cache, :default_errors, :error_logger, to: :@config
    delegate :where, to: :@client_klass

    def initialize config, client_klass, options = {}
      @config = config
      @client_klass = client_klass
      @key_base = client_klass.to_s.split("::")
      @options = options
    end

    def fetch ids
      records = FindByIds.new(self, ids).records

      records + missing_records(ids - records.map(&:id))
    end

    def key id
      @key_base + [id]
    end

    def expires_in
      @options.fetch :expires_in, @config.default_expires_in
    end

    private

    def missing_records ids
      ids.map { |id| MissingRecord.new id }
    end

    class FindByIds
      attr_reader :multi, :ids

      delegate :cache, to: :multi

      def initialize(multi, ids)
        @multi = multi
        @ids = ids
      end

      def records
        fresh_cached + direct + stale
      end

      private

      def fresh_cached
        @fresh_cached ||= cache.read_multi(*ids.map { |id| multi.key(id) }).values
      end

      def uncached_or_stale_ids
        ids - fresh_cached.map(&:id)
      end

      def direct
        @direct ||= if uncached_or_stale_ids.length > 0
          records = uncached_where id: uncached_or_stale_ids, per_page: uncached_or_stale_ids.length
          write_cache records
          records
        else
          []
        end
      end

      def write_cache records
        records.each do |record|
          key = Key.new(multi.key(record.id))
          key.write record, expires_in: multi.expires_in
          key.write_backup record
        end
      end

      def stale
        cache.read_multi(*(uncached_or_stale_ids - direct.map(&:id)).map { |id| [:backup_cache] + multi.key(id) }).values
      end

      def uncached_where params
        multi.where(params)
      rescue *multi.default_errors => e
        multi.error_logger.error e
        []
      end
    end
  end
end
