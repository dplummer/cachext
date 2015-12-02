require "active_support/core_ext/module/delegation"
require "active_support/core_ext/hash/keys"
require "active_support/core_ext/hash/reverse_merge"

module Cachext
  class Multi
    attr_reader :config, :key_base

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

    def heartbeat_expires
      @options.fetch :heartbeat_expires, config.heartbeat_expires
    end

    private

    def missing_records ids
      ids.map { |id| MissingRecord.new id }
    end

    class FindByIds
      attr_reader :multi, :ids

      delegate :config, :heartbeat_expires, to: :multi
      delegate :cache, :lock_manager, :max_lock_wait, to: :config

      def initialize multi, ids, lookup
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
          with_lock uncached_or_stale_ids do
            records = uncached_where uncached_or_stale_ids
            write_cache records
            records
          end
        else
          {}
        end
      rescue Features::Lock::TimeoutWaitingForLock => e
        config.error_logger.error e
        {}
      end

      def with_lock ids, &block
        @lock_info = obtain_lock ids
        block.call
      ensure
        lock_manager.unlock @lock_info if @lock_info
      end

      def obtain_lock ids
        lock_key = lock_key_from_ids ids

        start_time = Time.now

        until lock_info = lock_manager.lock(lock_key, (heartbeat_expires * 1000).ceil)
          sleep rand
          if Time.now - start_time > max_lock_wait
            raise Features::Lock::TimeoutWaitingForLock
          end
        end

        lock_info
      end

      def lock_key_from_ids(ids)
        key = Key.new multi.key_base + ids
        key.digest
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
        with_heartbeat_extender lock_key_from_ids(ids) do
          records = @lookup.call ids

          if records.is_a?(Array)
            records = records.each_with_object({}) do |record, acc|
              acc[record.id] = record
            end
          end

          delete_backups ids - records.keys
          records
        end
      rescue *config.default_errors => e
        config.error_logger.error e
        {}
      end

      def with_heartbeat_extender lock_key, &block
        done = false
        heartbeat_frequency = heartbeat_expires / 2

        Thread.new do
          loop do
            break if done
            sleep heartbeat_frequency
            break if done
            lock_manager.lock lock_key, (heartbeat_expires * 1000).ceil, extend: @lock_info
          end
        end

        block.call
      ensure
        lock_manager.unlock @lock_info
        done = true
      end
    end
  end
end
