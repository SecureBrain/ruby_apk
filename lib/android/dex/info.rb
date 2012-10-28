require_relative 'dex_object'

module Android
  class Dex
    # class information in dex
    # @!attribute [r] name
    #  @return [String] class name
    # @!attribute [r] super_class
    #  @return [String] super class name
    class ClassInfo
      # no index flag
      NO_INDEX = 0xffffffff

      # @return [ClassAccessFlag]
      attr_reader :access_flags
      # @return [Array<FieldInfo>] static fields
      attr_reader :static_fields
      # @return [Array<FieldInfo>] instance fields
      attr_reader :instance_fields
      # @return [Array<MethodInfo>] direct methods
      attr_reader :direct_methods
      # @return [Array<MethodInfo>] virtual methods
      attr_reader :virtual_methods

      # @return [DexObject::ClassDataItem]
      attr_reader :class_data
      # @return [DexObject::ClassDefItem]
      attr_reader :class_def

      def name
        @dex.type_resolve(@class_def[:class_idx])
      end
      def super_class
        if @class_def[:superclass_idx] != NO_INDEX
          @super_class = @dex.type_resolve(@class_def[:superclass_idx]) 
        else
          nil
        end
      end
      # @param [Dex::ClassDefItem] class_def
      # @param [Dex] dex dex class instance
      def initialize(class_def, dex)
        @class_def = class_def
        @dex = dex
        @access_flags = ClassAccessFlag.new(@class_def[:access_flags])
        @class_data = @class_def.class_data_item
        @static_fields = @instance_fields = @direct_methods = @virtual_methods = []
        unless @class_data.nil?
          @static_fields = cls2info(@class_data[:static_fields], FieldInfo, :field_idx_diff)
          @instance_fields = cls2info(@class_data[:instance_fields], FieldInfo, :field_idx_diff)
          @direct_methods = cls2info(@class_data[:direct_methods], MethodInfo, :method_idx_diff)
          @virtual_methods = cls2info(@class_data[:virtual_methods], MethodInfo, :method_idx_diff)
        end
      end

      # @return [String] class difinition
      def definition
        ret = "#{access_flags} class #{name}"
        super_class.nil? ? ret : ret + " extends #{super_class}"
      end

      private
      def cls2info(arr, cls, idx_key)
        idx = 0
        ret = []
        arr.each do |item|
          idx += item[idx_key]
          ret << cls.new(item, idx, @dex)
        end
        ret
      end
    end

    # field info object
    # @!attribute [r] name
    #  @return [String] field name
    # @!attribute [r] type
    #  @return [String] field type
    class FieldInfo
      # @return [ClassAccessFlag]
      attr_reader :access_flags

      def name
        @dex.strings[@dex.field_ids[@field_id][:name_idx]]
      end
      def type
        @dex.type_resolve(@dex.field_ids[@field_id][:type_idx])
      end
      def initialize(encoded_field, field_id, dex)
        @dex = dex
        @encoded_field = encoded_field
        @field_id = field_id
        @access_flags = ClassAccessFlag.new(encoded_field[:access_flags])
      end

      # @return [String] field definition
      def definition
        "#{@access_flags.to_s} #{type} #{name}"
      end
    end

    # method info object
    # @!attribute [r] name
    #  @return [String] method name
    # @!attribute [r] ret_type
    #  @return [String] return type of the method
    # @!attribute [r] parameters
    #  @return [Array<String>] method parameters
    class MethodInfo
      # @return [MethodAccessFlag]
      attr_reader :access_flags

      def initialize(encoded_method, method_id, dex)
        @encoded_method = encoded_method
        @method_id = method_id
        @dex = dex
        @access_flags = MethodAccessFlag.new(encoded_method[:access_flags])
      end
      def name
        @dex.strings[@dex.method_ids[@method_id][:name_idx]]
      end
      def ret_type
        @dex.type_resolve(proto[:return_type_idx])
      end
      def parameters
        unless proto[:parameters_off] == 0
          list = DexObject::TypeList.new(@dex.data, proto[:parameters_off])
          list[:list].map { |item| @dex.type_resolve(item) }
        else
          []
        end
      end

      # @return [String] method definition string
      def definition
        "#{access_flags.to_s} #{ret_type} #{name}(#{parameters.join(', ')});"
      end

      # @return [DexObject::CodeItem]
      def code_item
        @encoded_method.code_item
      end

      private
      def proto
        @dex.proto_ids[@dex.method_ids[@method_id][:proto_idx]]
      end
    end

  end
end
