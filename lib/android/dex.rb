require_relative 'dex/dex_object'
require_relative 'dex/info'
require_relative 'dex/access_flag'
require_relative 'dex/utils'

module Android
  # parsed dex object
  # @see http://source.android.com/devices/tech/dalvik/dex-format.html
  # @attr_reader strings [Array<String>] strings in dex file.
  class Dex
    # @return [Dex::Header] dex header information
    attr_reader :header
    alias :h :header

    # @return [String] dex binary data
    attr_reader :data
    # @return [Array<Dex::ClassInfo>] array of class information
    attr_reader :classes

    attr_reader :field_ids, :method_ids, :proto_ids
    # @param [String] data dex binary data
    def initialize(data)
      @data = data
      @data.force_encoding(Encoding::ASCII_8BIT)
      @classes = []
      parse()
    end

    def strings
      @strings ||= @string_data_items.map{|item| item.to_s }
    end

    def inspect
      "<Android::Dex @classes => #{@classes.size}, datasize => #{@data.size}>"
    end


    # @private
    TYPE_DESCRIPTOR = { 
      'V' => 'void',
      'Z' => 'boolean',
      'B' => 'byte',
      'S' => 'short',
      'C' => 'short',
      'I' => 'int',
      'J' => 'long',
      'F' => 'float',
      'D' => 'double'
    }


    def type_resolve(typeid)
      type = strings[@type_ids[typeid]]
      if type.start_with? '['
        type = type[1..type.size]
        return TYPE_DESCRIPTOR.fetch(type, type) + "[]" # TODO: recursive
      else
        return TYPE_DESCRIPTOR.fetch(type, type)
      end
    end


    private
    def parse
      @header = DexObject::Header.new(@data)
      @map_list = DexObject::MapList.new(@data, h[:map_off])

      # parse strings
      @string_ids = DexObject::StringIdItem.new(@data, h[:string_ids_off], h[:string_ids_size])
      @string_data_items = []
      @string_ids[:string_data_off].each { |off| @string_data_items << DexObject::StringDataItem.new(@data, off) }

      @type_ids = DexObject::TypeIdItem.new(@data, h[:type_ids_off], h[:type_ids_size])
      @proto_ids = ids_list_array(DexObject::ProtoIdItem, h[:proto_ids_off], h[:proto_ids_size])
      @field_ids = ids_list_array(DexObject::FieldIdItem, h[:field_ids_off], h[:field_ids_size])
      @method_ids = ids_list_array(DexObject::MethodIdItem, h[:method_ids_off], h[:method_ids_size])
      @class_defs = ids_list_array(DexObject::ClassDefItem, h[:class_defs_off], h[:class_defs_size])

      @classes = []
      @class_defs.each do |cls_def|
        @classes << ClassInfo.new(cls_def, self)
      end
    end

    def ids_list_array(cls, offset, size)
      ret_array = []
      size.times { |i| ret_array << cls.new(@data, offset + cls.size * i) }
      ret_array
    end
  end
end

