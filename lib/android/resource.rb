# encoding: utf-8
require 'stringio'
require 'csv'
require 'ruby_apk'

module Android
  # based on Android OS source code
  # /frameworks/base/include/utils/ResourceTypes.h
  class Resource
    class ChunkHeader
      attr_reader :type, :header_size, :size
      def initialize(data, offset)
        @data = data
        @offset = offset
        @data_io = StringIO.new(@data, 'rb')
        @data_io.seek(offset)
        parse
      end
      private
      def parse
        @type = read_int16
        @header_size = read_int16
        @size = read_int32
      end
      def read_int32
        @data_io.read(4).unpack('V')[0]
      end
      def read_int16
        @data_io.read(2).unpack('v')[0]
      end
    end

    class ResTableHeader < ChunkHeader
      attr_reader :package_count
      def parse
        super
        @package_count = read_int32
      end
    end
    class ResStringPool < ChunkHeader
      SORTED_FLAG = 1 << 0
      UTF8_FLAG = 1 << 8

      attr_reader :strings
      private
      def parse
        super
        @string_count = read_int32
        @style_count = read_int32
        @flags = read_int32
        @string_start = read_int32
        @style_start = read_int32
        @strings = []
        @string_count.times do
          offset = @offset + @string_start + read_int32
          if (@flags & UTF8_FLAG != 0)
            # read length twice(utf16 length and utf8 length)
            #  const uint16_t* ResStringPool::stringAt(size_t idx, size_t* u16len) const
            u16len, o16 = ResStringPool.utf8_len(@data[offset, 2])
            u8len, o8 = ResStringPool.utf8_len(@data[offset+o16, 2])
            str = @data[offset+o16+o8, u8len]
            @strings << str.force_encoding(Encoding::UTF_8)
          else
            u16len, o16 = ResStringPool.utf16_len(@data[offset, 4])
            str = @data[offset+o16, u16len*2]
            str.force_encoding(Encoding::UTF_16LE)
            @strings << str.encode(Encoding::UTF_8)
          end
        end
      end

      # @note refer to /frameworks/base/libs/androidfw/ResourceTypes.cpp
      #   static inline size_t decodeLength(const uint8_t** str)
      # @param [String] data parse target
      # @return[Integer, Integer] string length and parsed length
      def self.utf8_len(data)
        first, second = data.unpack('CC')
        if (first & 0x80) != 0
          return (((first & 0x7F) << 8) + second), 2
        else
          return first, 1
        end
      end
      # @note refer to /frameworks/base/libs/androidfw/ResourceTypes.cpp
      #   static inline size_t decodeLength(const char16_t** str)
      # @param [String] data parse target
      # @return[Integer, Integer] string length and parsed length
      def self.utf16_len(data)
        first, second = data.unpack('vv')
        if (first & 0x8000) != 0
          return (((first & 0x7FFF) << 16) + second), 4
        else
          return first, 2
        end
      end
    end

    ######################################################################
    def initialize(data)
      data.force_encoding(Encoding::ASCII_8BIT)
      @data = data
      parse()
    end

    def strings
      @string_pool.strings
    end
    def package_count
      @res_table.package_count
    end

    private
    def parse
      offset = 0

      while offset < @data.size
        type = @data[offset, 2].unpack('v')[0]
        case type
        when 0x0001 # RES_STRING_POOL_TYPE
          @string_pool = ResStringPool.new(@data, offset)
          offset += @string_pool.size
        when 0x0002 # RES_TABLE_TYPE
          @res_table = ResTableHeader.new(@data, offset)
          offset += @res_table.header_size
        when 0x0200, 0x0201, 0x0202
          # not implemented yet.
          chunk = ChunkHeader.new(@data, offset)
          offset += chunk.size
        else
          raise "chunk type error: type:%#04x" % type
        end
      end
    end
  end
end
