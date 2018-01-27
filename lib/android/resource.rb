# encoding: utf-8
require 'stringio'

module Android
  # based on Android OS source code
  # /frameworks/base/include/utils/ResourceTypes.h
  # @see http://justanapplication.wordpress.com/category/android/android-resources/
  class Resource
    class Chunk
      def initialize(data, offset)
        @data = data
        @offset = offset
        exec_parse
      end
      def exec_parse
        @data_io = StringIO.new(@data, 'rb')
        @data_io.seek(@offset)
        parse
        @data_io.close
      end
      def read_int32
        @data_io.read(4).unpack('V')[0]
      end
      def read_int16
        @data_io.read(2).unpack('v')[0]
      end
      def read_int8
        @data_io.read(1).ord
      end
      def current_position
        @data_io.pos
      end
    end

    class ChunkHeader < Chunk
      attr_reader :type, :header_size, :size
      private
      def parse
        @type = read_int16
        @header_size = read_int16
        @size = read_int32
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

    class ResTablePackage < ChunkHeader
      attr_reader :name

      def global_string_pool=(pool)
        @global_string_pool = pool
        extract_res_strings
      end

      # find resource by resource id
      # @param [String] res_id (like '@0x7f010001' or '@string/key')
      # @param [Hash] opts option
      # @option opts [String] :lang language code like 'ja', 'cn'...
      # @option opts [String] :contry cantry code like 'jp'...
      # @raise [ArgumentError] invalid id format
      # @note
      #  This method only support string and drawable/mipmap resource for now.
      # @note
      #  Always return nil if assign not string type res id.
      #
      def find(res_id, opts={})
        hex_id = strid2int(res_id)
        tid = ((hex_id&0xff0000) >>16)
        key = hex_id&0xffff

        case type(tid) 
        when 'string'
          return find_res_string(key, opts)
        when 'drawable', 'mipmap'
          drawables = []
          @types[tid].each do |type|
            unless type[key].nil?
              drawables << @global_string_pool.strings[type[key].val.data]
            end
          end
          return drawables
        else
          nil
        end
      end

      def res_types
      end
      def find_res_string(key, opts={})
        unless opts[:lang].nil?
          string = @res_strings_lang[opts[:lang]]
        end
        unless opts[:contry].nil?
          string = @res_strings_contry[opts[:contry]]
        end
        string = @res_strings_default if string.nil?
        raise NotFoundError unless string.has_key? key
        return string[key]
      end
      private :find_res_string

      # convert string resource id to fixnum
      # @param [String] res_id (like '@0x7f010001' or '@string/key')
      # @return [Fixnum] integer id (like 0x7f010001)
      # @raise [ArgumentError] invalid format
      def strid2int(res_id)
        case res_id
        when /^@?0x[0-9a-fA-F]{8}$/
          return res_id.sub(/^@/,'').to_i(16)
        when /^@?\w+\/\w+/
          return res_hex_id(res_id).sub(/^@/,'').to_i(16)
        else
          raise ArgumentError
        end
      end

      def res_readable_id(hex_id)
        if hex_id.kind_of? String
          hex_id = hex_id.sub(/^@/,'').to_i(16)
        end
        tid = ((hex_id&0xff0000) >>16)
        key = hex_id&0xffff
        raise NotFoundError if !@types.has_key?(tid) || @types[tid][0][key].nil?
        keyid= @types[tid][0][key].key # ugh!
        "@#{type(tid)}/#{key(keyid)}"
      end
      def res_hex_id(readable_id, opt={})
        dummy, typestr, keystr = readable_id.match(/^@?(\w+)\/(\w+)$/).to_a
        tid = type_id(typestr)
        raise NotFoundError unless @types.has_key?(tid)
        keyid = @types[tid][0].keys[keystr]
        raise NotFoundError if keyid.nil?
        "@0x7f%02x%04x" % [tid, keyid]
      end

      def type_strings
        @type_strings.strings
      end
      def type(id)
        type_strings[id-1]
      end
      def type_id(str)
        raise NotFoundError unless type_strings.include? str
        type_strings.index(str) + 1
      end
      def key_strings
        @key_strings.strings
      end
      def key(id)
        key_strings[id]
      end
      def key_id(str)
        raise NotFoundError unless key_strings.include? str
        key_strings.index(str) 
      end

      def parse
        super
        @id = read_int32
        @name = @data_io.read(256).force_encoding(Encoding::UTF_16LE)
        @name.encode!(Encoding::UTF_8).strip!
        type_strings_offset = read_int32
        @type_strings = ResStringPool.new(@data, @offset + type_strings_offset)
        @last_public_type = read_int32
        key_strings_offset = read_int32
        @key_strings = ResStringPool.new(@data, @offset + key_strings_offset)
        @last_public_key = read_int32

        offset = @offset + key_strings_offset + @key_strings.size

        @types = {}
        @specs = {}
        while offset < (@offset + @size)
          type = @data[offset, 2].unpack('v')[0]
          case type
          when 0x0201 # RES_TABLE_TYPE_TYPE
            type = ResTableType.new(@data, offset, self)
            offset += type.size
            @types[type.id] = [] if @types[type.id].nil?
            @types[type.id] << type
          when 0x0202 # RES_TABLE_TYPE_SPEC_TYPE`
            spec = ResTableTypeSpec.new(@data, offset)
            offset += spec.size
            @specs[spec.id] = [] if @specs[spec.id].nil?
            @specs[spec.id] << spec
          else
            raise "chunk type error: type:%#04x" % type
          end
        end
      end
      private :parse

      def extract_res_strings
        @res_strings_default = {}
        @res_strings_lang = {}
        @res_strings_contry = {}
        begin
          type = type_id('string')
        rescue NotFoundError
          return
        end
        @types[type_id('string')].each do |type|
          str_hash  = {}
          type.entry_count.times do |i|
            entry = type[i]
            if entry.nil?
              str_hash[i] = nil
            else
              str_hash[i] = @global_string_pool.strings[type[i].val.data]
            end
          end
          lang = type.config.locale_lang
          contry = type.config.locale_contry
          hash_merge_resolver = proc { |_, *values| values.compact.first }
          if lang.nil? && contry.nil?
            @res_strings_default.merge!(str_hash, &hash_merge_resolver)
          else
            @res_strings_lang[lang] = (@res_strings_lang[lang] || {}).merge(str_hash, &hash_merge_resolver) unless lang.nil?
            @res_strings_contry[contry] = (@res_strings_contry[contry] || {}).merge(str_hash, &hash_merge_resolver) unless contry.nil?
          end
        end
      end
      private :extract_res_strings

      def inspect
        "<ResTablePackage offset:%#08x, size:%#x, name:\"%s\">" % [@offset, @size, @name]
      end
    end

    class ResTableType < ChunkHeader
      attr_reader :id, :entry_count, :entry_start, :config
      attr_reader :keys

      def initialize(data, offset, pkg)
        @pkg = pkg
        super(data, offset)
      end
      # @param [String] index key name
      # @param [Fixnum] index key index
      # @return [ResTableEntry]
      # @return [ResTableMapEntry]
      # @return nil if entry index is NO_ENTRY(0xFFFFFFFF)
      def [](index)
        @entries[index]
      end

      def parse
        super
        @id = read_int8
        res0 = read_int8   # must be 0.(maybe 4byte align)
        res1 = read_int16  # must be 0.(maybe 4byte align)
        @entry_count = read_int32
        @entry_start = read_int32
        @config = ResTableConfig.new(@data, current_position)
        @data_io.seek(@config.size, IO::SEEK_CUR)

        @entries = []
        @keys = {}
        @entry_count.times do |i|
          entry_index = read_int32
          if entry_index == ResTableEntry::NO_ENTRY
            @entries << nil
          else
            entry = ResTableEntry.read_entry(@data, @offset + @entry_start + entry_index)
            @entries << entry
            @keys[@pkg.key(entry.key)] = i
          end
        end
      end
      private :parse


      def inspect
        "<ResTableType offset:0x#{@offset.to_s(16)}, id:#{@id}, " +
        "count:#{@entry_count}, start:0x#{@entry_start.to_s(16)}>"
      end
    end

    class ResTableConfig < Chunk
      attr_reader :size, :imei, :locale_lang, :locale_contry, :input
      attr_reader :screen_input, :version, :screen_config
      def parse
        @size = read_int32
        @imei = read_int32
        la = @data_io.read(2)
        @locale_lang = la unless la == "\x00\x00"
        cn = @data_io.read(2)
        @locale_contry = cn unless cn == "\x00\x00"
        @screen_type = read_int32
        @input = read_int32
        @screen_input = read_int32
        @version = read_int32
        @screen_config = read_int32
      end
      def inspect
        "<ResTableConfig size:#{@size}, imei:#{@imei}, la:'#{@locale_lang}' cn:'#{@locale_contry}'"
      end
    end

    class ResTableTypeSpec < ChunkHeader
      attr_reader :id, :entry_count

      def parse
        super
        @id = read_int8
        res0 = read_int8 # must be 0.(maybe 4byte align)
        res1 = read_int16 # must be 0.(maybe 4byte align)
        @entry_count = read_int32
      end
      private :parse

      def inspect
        "<ResTableTypeSpec id:#{@id} entry count:#{@entry_count}>"
      end
    end
    class ResTableEntry < Chunk
      NO_ENTRY = 0xFFFFFFFF

      # @return [ResTableEntry] if not set FLAG_COMPLEX
      # @return [ResTableMapEntry] if not set FLAG_COMPLEX
      def self.read_entry(data, offset)
        flag = data[offset + 2, 2].unpack('v')[0]
        if flag & ResTableEntry::FLAG_COMPLEX == 0
          ResTableEntry.new(data, offset)
        else
          ResTableMapEntry.new(data, offset)
        end
      end

      # If set, this is a complex entry, holding a set of name/value
      # mappings.  It is followed by an array of ResTable_map structures.
      FLAG_COMPLEX = 0x01
      # If set, this resource has been declared public, so libraries
      # are allowed to reference it.
      FLAG_PUBLIC  = 0x02

      attr_reader :size, :key, :val
      def parse
        @size = read_int16
        @flag = read_int16
        @key = read_int32 # RefStringPool_key
        @val = ResValue.new(@data, current_position)
      end
      private :parse

      def inspect
        "<ResTableEntry @size=#{@size}, @key=#{@key} @flag=#{@flag}>"
      end
    end
    class ResTableMapEntry < ResTableEntry
      attr_reader :parent, :count
      def parse
        super
        # resource identifier of the parent mapping, 0 if there is none.
        @parent = read_int32
        # number of name/value pairs that follw for FLAG_COMPLEX
        @count = read_int32
        # TODO: implement read ResTableMap object
      end
      private :parse
    end
    class ResTableMap < Chunk
      def size
        @val.size + 4
      end
      def parse
        @name = read_int32
       @val = ResValue.new(@data, current_position)
      end
    end

    class ResValue < Chunk
      attr_reader :size, :data_type, :data
      def parse
        @size = read_int16
        res0 = read_int8 # Always set 0.
        @data_type = read_int8
        @data = read_int32
      end
      private :parse
    end

    ######################################################################
    # @returns [Hash] { name(String) => value(ResTablePackage) }
    attr_reader :packages

    def initialize(data)
      data.force_encoding(Encoding::ASCII_8BIT)
      @data = data
      parse()
    end


    # @return [Array<String>] all strings defined in arsc.
    def strings
      @string_pool.strings
    end

    # @return [Fixnum] number of packages
    def package_count
      @res_table.package_count
    end

    #  This method only support string resource for now.
    # find resource by resource id
    # @param [String] res_id (like '@0x7f010001' or '@string/key')
    # @param [Hash] opts option
    # @option opts [String] :lang language code like 'ja', 'cn'...
    # @option opts [String] :contry cantry code like 'jp'...
    # @raise [ArgumentError] invalid id format
    # @note
    #  This method only support string resource for now.
    # @note
    #  Always return nil if assign not string type res id.
    # @since 0.5.0
    def find(rsc_id, opt={})
      first_pkg.find(rsc_id, opt)
    end

    # @param [String] hex_id hexoctet format resource id('@0x7f010001')
    # @return [String] readable resource id ('@string/key')
    # @since 0.5.0
    def res_readable_id(hex_id)
      first_pkg.res_readable_id(hex_id)
    end

    # convert readable resource id to hex id
    # @param [String] readable_id readable resource id ('@string/key')
    # @return [String] hexoctet format resource id('@0x7f010001')
    # @since 0.5.0
    def res_hex_id(readable_id)
      first_pkg.res_hex_id(readable_id)
    end

    def first_pkg
      @packages.first[1]
    end
    private
    def parse
      offset = 0

      while offset < @data.size
        type = @data[offset, 2].unpack('v')[0]
        #print "[%#08x] " % offset
        @packages = {}
        case type
        when 0x0001 # RES_STRING_POOL_TYPE
          @string_pool = ResStringPool.new(@data, offset)
          offset += @string_pool.size
          #puts "RES_STRING_POOL_TYPE %#x, %#x" % [@string_pool.size, offset]
        when 0x0002 # RES_TABLE_TYPE
          #puts "RES_TABLE_TYPE"
          @res_table = ResTableHeader.new(@data, offset)
          offset += @res_table.header_size
        when 0x0200 # RES_TABLE_PACKAGE_TYPE
          #puts "RES_TABLE_PACKAGE_TYPE"
          pkg = ResTablePackage.new(@data, offset)
          pkg.global_string_pool = @string_pool
          offset += pkg.size
          @packages[pkg.name] = pkg
        else
          raise "chunk type error: type:%#04x" % type
        end
      end
    end
  end
end
