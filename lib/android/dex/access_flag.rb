
module Android
  class Dex
    # access flag object
    class AccessFlag
      # @return [Integer] flag value
      attr_reader :flag
      def initialize(flag)
        @flag = flag
      end
    end

    # access flag object for class in dex
    class ClassAccessFlag < AccessFlag
      ACCESSORS = [
        {value:0x1,     name:'public'},
        {value:0x2,     name:'private'},
        {value:0x4,     name:'protected'},
        {value:0x8,     name:'static'},
        {value:0x10,    name:'final'},
        {value:0x20,    name:'synchronized'},
        {value:0x40,    name:'volatile'},
        {value:0x80,    name:'transient'},
        {value:0x100,   name:'native'},
        {value:0x200,   name:'interface'},
        {value:0x400,   name:'abstract'},
        {value:0x800,   name:'strict'},
        {value:0x1000,  name:'synthetic'},
        {value:0x2000,  name:'annotation'},
        {value:0x4000,  name:'enum'},
        #{value:0x8000,  name:'unused'},
        {value:0x10000, name:'constructor'},
        {value:0x20000, name:'declared-synchronized'},
      ]

      # convert access flag to string
      # @return [String]
      def to_s
        ACCESSORS.select{|e| ((e[:value] & @flag) != 0) }.map{|e| e[:name] }.join(' ')
      end
    end
   
    # access flag object for method in dex
    class MethodAccessFlag < AccessFlag
      ACCESSORS = [
        {value: 0x1,     name:'public'},
        {value: 0x2,     name:'private'},
        {value: 0x4,     name:'protected'},
        {value: 0x8,     name:'static'},
        {value: 0x10,    name:'final'},
        {value: 0x20,    name:'synchronized'},
        {value: 0x40,    name:'bridge'},
        {value: 0x80,    name:'varargs'},
        {value: 0x100,   name:'native'},
        {value: 0x200,   name:'interface'},
        {value: 0x400,   name:'abstract'},
        {value: 0x800,   name:'strict'},
        {value: 0x1000,  name:'synthetic'},
        {value: 0x2000,  name:'annotation'},
        {value: 0x4000,  name:'enum'},
        #{value: 0x8000,  name:'unused'},
        {value: 0x10000, name:'constructor'},
        {value: 0x20000, name:'declared-synchronized'},
      ]
      # convert access flag to string
      # @return [String]
      def to_s
        ACCESSORS.select{|e| ((e[:value] & @flag) != 0) }.map{|e| e[:name] }.join(' ')
      end
    end
  end
end


