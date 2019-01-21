module KmsEncrypted
  class Database
    attr_reader :record, :key_method, :options

    def initialize(record, key_method)
      @record = record
      @key_method = key_method
      @options = record.class.kms_keys[key_method.to_sym]
    end

    def version
      @version ||= begin
        version = options[:version]
        version = record.instance_exec(&version) if version.respond_to?(:call)
        version.to_i
      end
    end

    def key_id
      @key_id ||= begin
        key_id = options[:key_id]
        key_id = record.instance_exec(&key_id) if key_id.respond_to?(:call)
        key_id
      end
    end

    def context(version)
      name = options[:name]
      context_method = name ? "kms_encryption_context_#{name}" : "kms_encryption_context"
      if record.method(context_method).arity == 0
        record.send(context_method)
      else
        record.send(context_method, version: version)
      end
    end

    def encrypt(plaintext)
      context = context(version)

      KmsEncrypted::Box.new(
        key_id: key_id,
        version: version,
        previous_versions: options[:previous_versions]
      ).encrypt(plaintext, context: context)
    end

    def decrypt(ciphertext)
      # determine version for context
      m = /\Av(\d+):/.match(ciphertext)
      version = m ? m[1].to_i : 1
      context = (options[:upgrade_context] && !m) ? {} : context(version)

      KmsEncrypted::Box.new(
        key_id: key_id,
        previous_versions: options[:previous_versions]
      ).decrypt(ciphertext, context: context)
    end
  end
end
