require "active_support/core_ext/module/delegation"
require "active_support/core_ext/hash/keys"
require "active_support/core_ext/hash/reverse_merge"

module Cachext
  class Multi
    delegate :cache, :default_errors, :error_logger, to: :@config

    def initialize config, key_base, options = {}
      @config = config
      @key_base = key_base
      @options = options
    end

    def fetch ids, &block
      records = FindByIds.new(self, ids, block).records

      if @options.fetch(:return_array, false)
        records.values + missing_records(ids - records.keys)
      else
        records
      end
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

      def initialize(multi, ids, lookup)
        @multi = multi
        @ids = ids
        @lookup = lookup
      end

      def records
        fresh_cached.merge(direct).reverse_merge(stale)
      end

      private

      def fresh_cached
        @fresh_cached ||= cache.read_multi(*ids.map { |id| multi.key(id) }).
          transform_keys { |key| key.last }
      end

      def uncached_or_stale_ids
        ids - fresh_cached.keys
      end

      def direct
        @direct ||= if uncached_or_stale_ids.length > 0
          records = uncached_where uncached_or_stale_ids
          write_cache records
          records
        else
          {}
        end
      end

      def write_cache records
        records.each do |id, record|
          key = Key.new(multi.key(id))
          key.write record, expires_in: multi.expires_in
          key.write_backup record
        end
      end

      def delete_backups ids
        return if ids.blank?

        ids.each do |id|
          key = Key.new(multi.key(id))
          key.delete_backup
        end
      end

      def stale
        cache.read_multi(*(uncached_or_stale_ids - direct.keys).map { |id| [:backup_cache] + multi.key(id) }).
          transform_keys { |key| key.last }
      end

      def uncached_where ids
        records = @lookup.call ids
        delete_backups ids - records.keys
        records
      rescue *multi.default_errors => e
        multi.error_logger.error e
        {}
      end
    end
  end
end
