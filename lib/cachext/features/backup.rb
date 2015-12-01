module Cachext
  module Features
    module Backup
      def handle_not_found key, options, error
        key.delete_backup
        super
      end

      def handle_error key, options, error
        super
        key.read_backup
      end

      def write key, fresh, options
        super
        key.write_backup fresh
      end
    end
  end
end
