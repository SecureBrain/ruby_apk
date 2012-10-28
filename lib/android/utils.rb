
module Android
  # Utility methods
  module Utils
    # path is apk file or not.
    # @param [String] path target file path
    # @return [Boolean]
    def self.apk?(path)
      begin
        apk = Apk.new(path)
        return true
      rescue => e
        return false
      end
    end

    # data is elf file or not.
    # @param [String] data target data
    # @return [Boolean]
    def self.elf?(data)
      data[0..3] == "\x7f\x45\x4c\x46"
    rescue => e
      false
    end

    # data is cert file or not.
    # @param [String] data target data
    # @return [Boolean]
    def self.cert?(data)
      data[0..1] == "\x30\x82"
    rescue => e
      false
    end

    # data is dex file or not.
    # @param [String] data target data
    # @return [Boolean]
    def self.dex?(data)
      data[0..7] == "\x64\x65\x78\x0a\x30\x33\x35\x00" # "dex\n035\0"
    rescue => e
      false
    end

    # data is valid dex file or not.
    # @param [String] data target data
    # @return [Boolean]
    def self.valid_dex?(data)
      Android::Dex.new(data)
      true
    rescue => e
      false
    end
  end
end

