
module Android
  class Dex
    # parsing dex object
    # @see http://source.android.com/devices/tech/dalvik/dex-format.html
    class DexObject
      # @return [Integer] object size
      attr_reader :size

      def initialize(data, offset)
        @data = data
        @offset = offset

        @params = {}
        @parsing_off = 0 # parsing offset
        parse()
        @size = @parsing_off
      end
 
      # returns symbol keys
      # @return [Array<Symbol>] header key
      def symbols
        @params.keys
      end

      # @param [Symbol] sym should be included in #symbols
      # @return [Object] dex header value which is related with sym
      def [](sym)
        @params[sym.to_sym]
      end

      # @return [String]
      def inspect
        str = "<#{self.class}\n"
        @params.each  do |key,val|
          str.concat "    #{key}: #{val}\n"
        end
        str.concat '>'
      end

      private
      def parse
        raise 'this method should be overloaded.'
      end

      def read_value(type)
        types = {
          :byte   => [1, 'c'],
          :ubyte  => [1, 'C'],
          :short  => [2, 's'], #ugh!:depend on machine endian
          :ushort => [2, 'v'],
          :int    => [4, 'i'], #ugh!:depend on machine endian
          :uint   => [4, 'V'],
          :long   => [8, 'q'],
          :ulong  => [8, 'Q'],
        }
        len, pack_str = types.fetch(type)
        value = @data[@offset+@parsing_off, len].unpack(pack_str)[0]
        @parsing_off += len
        return value
      end

      # read short int from data buffer
      # @return [Integer] short value
      def read_sleb
        value, len = Dex::sleb128(@data, @offset + @parsing_off)
        @parsing_off += len
        value
      end
      # read integer from data buffer
      # @return [Integer] integer value
      def read_uleb
        value, len = Dex::uleb128(@data, @offset + @parsing_off)
        @parsing_off += len
        value
      end
      # read integer from data buffer and plus 1
      # @return [Integer] integer value
      def read_uleb128p1
        value, len = Dex::uleb128p1(@data, @offset + @parsing_off)
        @parsing_off += len
        value
      end
      # read various values from data buffer as array
      # @param [Symbol] type 
      # @param [Integer] size num of data
      # @return [Array] value array
      def read_value_array(type, size)
        ret_array = []
        size.times { ret_array << read_value(type) }
        ret_array
      end
      # read class values from data buffer as array
      # @param [Class] cls target class
      # @param [Integer] size num of data
      # @return [Array<cls>] object array
      def read_class_array(cls, size)
        ret_array = []
        size.times do
          item = cls.new(@data, @offset + @parsing_off)
          ret_array << item
          @parsing_off += item.size
        end
        ret_array
      end

      public
      # header_item
      # @see http://source.android.com/devices/tech/dalvik/dex-format.html
      class Header < DexObject
        def initialize(data)
          super(data, 0)
        end

        private
        def parse
          @params[:magic] = @data[0, 8]
          @parsing_off += 8
          @params[:checksum] = read_value(:uint)
          @params[:signature] = @data[12, 20]
          @parsing_off += 20
          [
            :file_size, :header_size, :endian_tag, :link_size, :link_off, :map_off,
            :string_ids_size, :string_ids_off, :type_ids_size, :type_ids_off,
            :proto_ids_size, :proto_ids_off, :field_ids_size, :field_ids_off,
            :method_ids_size, :method_ids_off, :class_defs_size, :class_defs_off,
            :data_size, :data_off
          ].each do |key|
            @params[key] = read_value(:uint)
          end
        end
      end

      # map_list
      # @see http://source.android.com/devices/tech/dalvik/dex-format.html
      class MapList < DexObject
        private
        def parse
          @params[:size] = read_value(:uint)
          @params[:list] = read_class_array(MapItem, @params[:size])
        end
      end

      # map_item
      # @see http://source.android.com/devices/tech/dalvik/dex-format.html
      class MapItem < DexObject
        private
        def parse
          @params[:type] = read_value(:short)
          @params[:unused] = read_value(:short)
          @params[:size] = read_value(:uint)
          @params[:offset] = read_value(:uint)
        end
      end

      # id_list
      # @see http://source.android.com/devices/tech/dalvik/dex-format.html
      class IdsList < DexObject
        attr_reader :ids_size
        def initialize(data, off, ids_size)
          @ids_size = ids_size
          super(data, off)
        end
      end

      # string_id_item
      # @see http://source.android.com/devices/tech/dalvik/dex-format.html
      class StringIdItem < IdsList
        private
        def parse
          @params[:string_data_off] = read_value_array(:uint, @ids_size)
        end
      end

      # string_data_item
      # @see http://source.android.com/devices/tech/dalvik/dex-format.html
      class StringDataItem < DexObject
        def to_s
          @params[:data]
        end
        private
        def mutf8_to_utf8(data, off, ulen)
          mi = 0 # index of mutf8 data
          codepoints = []
          while ulen > 0 do
            b0 = data[off + mi].ord
            bu = (b0 & 0xf0) # b0's upper nibble
            if (b0 & 0x80) == 0 # single byte encoding (0b0xxx_xxxx)
              c = b0
              mi += 1
              ulen -= 1
            elsif bu == 0xc0 || bu == 0xd0 # two-byte encoding (0b110x_xxxx)
              b1 = data[off + mi + 1].ord
              c = (b0 & 0x1f) << 6 | (b1 & 0x3f)
              mi += 2
              ulen -= 1
            elsif bu == 0xe0 # three-byte encoding (0b1110_xxxx)
              b1 = data[off + mi + 1].ord
              b2 = data[off + mi + 2].ord
              c = (b0 & 0x0f) << 12 | (b1 & 0x3f) << 6 | (b2 & 0x3f)
              mi += 3
              ulen -= 1
              if 0xD800 <= c && c <= 0xDBFF  # this must be a surrogate pair
                b4 = data[off + mi + 1].ord
                b5 = data[off + mi + 2].ord
                c = ((b1 & 0x0f) + 1) << 16 | (b2 & 0x3f) << 10 | (b4 & 0x0f) << 6 | (b5 & 0x3f)
                mi += 3
                ulen -= 1
              end
            else
              STDERR.puts "unsupported byte: 0x#{'%02X' % b0} @#{mi}"
              c = 0
              mi += 1
              next
            end
            if c != 0
              codepoints << c
            end
          end
          codepoints.pack("U*")
        end
        def parse
          @params[:utf16_size] = read_uleb
          @params[:data] = mutf8_to_utf8(@data, @offset + @parsing_off, @params[:utf16_size])
        end
      end

      # type_id_item
      # @see http://source.android.com/devices/tech/dalvik/dex-format.html
      class TypeIdItem < IdsList
        def [](idx)
          raise ArgumentError if idx >= @params[:descriptor_idx].size or idx < 0
          @params[:descriptor_idx][idx]
        end

        private
        def parse
          @params[:descriptor_idx] = read_value_array(:uint, @ids_size)
        end
      end

      # proto_id_item
      # @see http://source.android.com/devices/tech/dalvik/dex-format.html
      class ProtoIdItem < DexObject
        # return parse data size
        # @return bytes
        # @note this method for DexObject#read_class_array (private method)
        def self.size
          4 * 3
        end
        private
        def parse
          @params[:shorty_idx] = read_value(:uint)
          @params[:return_type_idx] = read_value(:uint)
          @params[:parameters_off] = read_value(:uint)
        end
      end

      # field_id_item
      # @see http://source.android.com/devices/tech/dalvik/dex-format.html
      class FieldIdItem < DexObject
        # return parse data size
        # @return bytes
        # @note this method for DexObject#read_class_array (private method)
        def self.size
          2 * 2 + 4 
        end
        private
        def parse
          @params[:class_idx] = read_value(:ushort)
          @params[:type_idx] = read_value(:ushort)
          @params[:name_idx] = read_value(:uint)
        end
      end

      # method_id_item
      # @see http://source.android.com/devices/tech/dalvik/dex-format.html
      class MethodIdItem < DexObject
        # return parse data size
        # @return bytes
        # @note this method for DexObject#read_class_array (private method)
        def self.size
          2 * 2 + 4 
        end
        def parse
          @params[:class_idx] = read_value(:ushort)
          @params[:proto_idx] = read_value(:ushort)
          @params[:name_idx] = read_value(:uint)
        end
      end

      # class_def_item
      # @see http://source.android.com/devices/tech/dalvik/dex-format.html
      # @!attribute [r] class_data_item
      #  @return [ClassDataItem] class_data_item of this class
      class ClassDefItem < DexObject
        # @return [Integer] bytes
        def self.size
          4 * 8
        end

        def class_data_item
          # description of class_data_off of class_def_item.
          #   offset from the start of the file to the associated class data
          #   for this item, or 0 if there is no class data for this class.
          if @params[:class_data_off] != 0
            @class_data_item ||= ClassDataItem.new(@data, @params[:class_data_off])
          else
            nil
          end
        end

        private
        def parse
          @params[:class_idx] = read_value(:uint)
          @params[:access_flags] = read_value(:uint)
          @params[:superclass_idx] = read_value(:uint)
          @params[:interfaces_off] = read_value(:uint)
          @params[:source_file_idx] = read_value(:uint)
          @params[:annotations_off] = read_value(:uint)
          @params[:class_data_off] = read_value(:uint)
          @params[:static_values_off] = read_value(:uint) # TODO: not implemented encoded_array_item
        end
      end

      # class_data_item
      # @see http://source.android.com/devices/tech/dalvik/dex-format.html
      class ClassDataItem < DexObject
        private
        def parse
          @params[:static_fields_size] = read_uleb
          @params[:instance_fields_size] = read_uleb
          @params[:direct_methods_size] = read_uleb
          @params[:virtual_methods_size] = read_uleb
          @params[:static_fields] = read_class_array(EncodedField, @params[:static_fields_size])
          @params[:instance_fields] = read_class_array(EncodedField, @params[:instance_fields_size])
          @params[:direct_methods] = read_class_array(EncodedMethod, @params[:direct_methods_size])
          @params[:virtual_methods] = read_class_array(EncodedMethod, @params[:virtual_methods_size])
        end
      end

      # encoded_field
      # @see http://source.android.com/devices/tech/dalvik/dex-format.html
      class EncodedField < DexObject
        private
        def parse
          @params[:field_idx_diff] = read_uleb
          @params[:access_flags] = read_uleb
        end
      end

      # encoded_method
      # @see http://source.android.com/devices/tech/dalvik/dex-format.html
      # @!attribute [r] code_item
      #  @return [CodeItem] code_item of the method
      class EncodedMethod < DexObject
        def code_item
          # description of code_off in code_data_item.
          #   offset from the start of the file to the code structure for this method,
          #   or 0 if this method is either abstract or native.
          unless @params[:code_off] == 0
            @code_item ||= CodeItem.new(@data, @params[:code_off])
          else
            nil
          end
        end

        private
        def parse
          @params[:method_idx_diff] = read_uleb
          @params[:access_flags] = read_uleb
          @params[:code_off] = read_uleb
        end
      end


      # type_list
      # @see http://source.android.com/devices/tech/dalvik/dex-format.html
      class TypeList < DexObject
        private
        def parse
          @params[:size] = read_value(:uint)
          @params[:list] = read_value_array(:ushort, @params[:size])
        end
      end

      # code_item
      # @see http://source.android.com/devices/tech/dalvik/dex-format.html
      # @!attribute [r] debug_info_item
      #  @return [DebugInfoItem] debug_info_item of this code
      class CodeItem < DexObject
        def debug_info_item
          unless @params[:debug_info_off] == 0
            @debug_info_item ||= DebugInfoItem.new(@data, @params[:debug_info_off])
          else
            nil
          end
        end

        private
        def parse
          @params[:registers_size] = read_value(:ushort)
          @params[:ins_size] = read_value(:ushort)
          @params[:outs_size] = read_value(:ushort)
          @params[:tries_size] = read_value(:ushort)
          @params[:debug_info_off] = read_value(:uint)
          @params[:insns_size] = read_value(:uint) # size of the instructions list
          @params[:insns] = read_value_array(:ushort, @params[:insns_size])
          read_value(:ushort) if ((@params[:insns_size] % 2) == 1) # for four-byte aligned
          if @params[:tries_size] > 0
            # This element is only present if tries_size is non-zero.
            @params[:tries] = read_class_array(TryItem, @params[:tries_size])
            # This element is only present if tries_size is non-zero.
            @params[:handlers] = EncodedCatchHandlerList.new(@data, @offset + @parsing_off)
            @parsing_off += @params[:handlers].size
          end
        end
      end

      # try_item
      # @see http://source.android.com/devices/tech/dalvik/dex-format.html
      class TryItem < DexObject
        private
        def parse
          @params[:start_addr] = read_value(:uint)
          @params[:insn_count] = read_value(:ushort)
          @params[:handler_off] = read_value(:ushort)
        end
      end

      # encoded_catch_handler_list
      # @see http://source.android.com/devices/tech/dalvik/dex-format.html
      class EncodedCatchHandlerList < DexObject
        private
        def parse
          @params[:size] = read_uleb
          @params[:list] = read_class_array(EncodedCatchHandler, @params[:size])
        end
      end

      # encoded_catch_handler
      # @see http://source.android.com/devices/tech/dalvik/dex-format.html
      class EncodedCatchHandler < DexObject
        private
        def parse
          @params[:size] = read_sleb
          @params[:list] = read_class_array(EncodedTypeAddrPair, @params[:size].abs)
          @params[:catch_all_addr] = read_uleb if @params[:size] <= 0
        end
      end

      # encoded_type_addr_pair
      # @see http://source.android.com/devices/tech/dalvik/dex-format.html
      class EncodedTypeAddrPair < DexObject
        private
        def parse
          @params[:type_idx] = read_uleb
          @params[:addr] = read_uleb
        end
      end

      # debug_info_item
      # @see http://source.android.com/devices/tech/dalvik/dex-format.html
      class DebugInfoItem < DexObject
        private
        def parse
          @params[:line_start] = read_uleb
          @params[:parameters_size] = read_uleb
          @params[:parameter_names] = []
          @params[:parameters_size].times { @params[:parameter_names] << read_uleb128p1 }
        end
      end
    end
  end
end
