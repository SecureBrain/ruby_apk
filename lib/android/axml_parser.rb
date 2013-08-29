require 'rexml/document'
require 'stringio'


module Android
  # binary AXML parser
  # @see https://android.googlesource.com/platform/frameworks/base.git Android OS frameworks source
  # @note
  #   refer to Android OS framework code:
  #   
  #   /frameworks/base/include/androidfw/ResourceTypes.h,
  #   
  #   /frameworks/base/libs/androidfw/ResourceTypes.cpp
  class AXMLParser
    def self.axml?(data)
      (data[0..3] == "\x03\x00\x08\x00")
    end

    # axml parse error
    class ReadError < StandardError; end

    TAG_START_DOC = 0x00100100
    TAG_END_DOC =   0x00100101
    TAG_START =     0x00100102
    TAG_END =       0x00100103
    TAG_TEXT =      0x00100104
    TAG_CDSECT =    0x00100105
    TAG_ENTITY_REF= 0x00100106

    VAL_TYPE_NULL              =0
    VAL_TYPE_REFERENCE         =1
    VAL_TYPE_ATTRIBUTE         =2
    VAL_TYPE_STRING            =3
    VAL_TYPE_FLOAT             =4
    VAL_TYPE_DIMENSION         =5
    VAL_TYPE_FRACTION          =6
    VAL_TYPE_INT_DEC           =16
    VAL_TYPE_INT_HEX           =17
    VAL_TYPE_INT_BOOLEAN       =18
    VAL_TYPE_INT_COLOR_ARGB8   =28
    VAL_TYPE_INT_COLOR_RGB8    =29
    VAL_TYPE_INT_COLOR_ARGB4   =30
    VAL_TYPE_INT_COLOR_RGB4    =31

    # @return [Array<String>] strings defined in axml
    attr_reader :strings

    # @param [String] axml binary xml data
    def initialize(axml)
      @io = StringIO.new(axml, "rb")
      @strings = []
    end

    # parse binary xml
    # @return [REXML::Document]
    def parse
      @doc = REXML::Document.new
      @doc << REXML::XMLDecl.new

      @num_str = word(4*4)
      @xml_offset = word(3*4)

      @parents = [@doc]
      @ns = []
      parse_strings
      parse_tags
      @doc
    end


    # read one word(4byte) as integer
    # @param [Integer] offset offset from top position. current position is used if ofset is nil
    # @return [Integer] little endian word value
    def word(offset=nil)
      @io.pos = offset unless offset.nil?
      @io.read(4).unpack("V")[0]
    end

    # read 2byte as short integer
    # @param [Integer] offset offset from top position. current position is used if ofset is nil
    # @return [Integer] little endian unsign short value
    def short(offset)
      @io.pos = offset unless offset.nil?
      @io.read(2).unpack("v")[0]
    end

    # relace string table parser
    def parse_strings
      strpool = Resource::ResStringPool.new(@io.string, 8) # ugh!
      @strings = strpool.strings
    end

    # parse tag
    def parse_tags
      # skip until START_TAG
      pos = @xml_offset
      pos += 4 until (word(pos) == TAG_START) #ugh!
      @io.pos -= 4

      # read tags
      #puts "start tag parse: %d(%#x)" % [@io.pos, @io.pos]
      until @io.eof?
        last_pos = @io.pos
        tag, tag1, line, tag3, ns_id, name_id = @io.read(4*6).unpack("V*")
        case tag
        when TAG_START
          tag6, num_attrs, tag8  = @io.read(4*3).unpack("V*")
          elem = REXML::Element.new(@strings[name_id])
          #puts "start tag %d(%#x): #{@strings[name_id]} attrs:#{num_attrs}" % [last_pos, last_pos]
          @parents.last.add_element elem
          num_attrs.times do
            key, val = parse_attribute
            elem.add_attribute(key, val)
          end
          @parents.push elem
        when TAG_END
          @parents.pop
        when TAG_END_DOC
          break
        when TAG_TEXT
          text = REXML::Text.new(@strings[ns_id])
          @parents.last.text = text
          dummy = @io.read(4*1).unpack("V*") # skip 4bytes
        when TAG_START_DOC, TAG_CDSECT, TAG_ENTITY_REF
          # not implemented yet.
        else
          raise ReadError, "pos=%d(%#x)[tag:%#x]" % [last_pos, last_pos, tag]
        end
      end
    end

    # parse attribute of a element
    def parse_attribute
      ns_id, name_id, val_str_id, flags, val = @io.read(4*5).unpack("V*")
      key = @strings[name_id]
      unless ns_id == 0xFFFFFFFF
        ns = @strings[ns_id] 
        prefix = ns.sub(/.*\//,'')
        unless @ns.include? ns
          @ns << ns
          @doc.root.add_namespace(prefix, ns)
        end
        key = "#{prefix}:#{key}"
      end
      value = convert_value(val_str_id, flags, val)
      return key, value
    end


    def convert_value(val_str_id, flags, val)
      unless val_str_id == 0xFFFFFFFF
        value = @strings[val_str_id]
      else
        type = flags >> 24
        case type
        when VAL_TYPE_NULL
          value = nil
        when VAL_TYPE_REFERENCE
          value = "@%#x" % val # refered resource id.
        when VAL_TYPE_INT_DEC
          value = val
        when VAL_TYPE_INT_HEX
          value = "%#x" % val
        when VAL_TYPE_INT_BOOLEAN
          value = ((val == 0xFFFFFFFF) || (val==1)) ? true : false
        else
          value = "[%#x, flag=%#x]" % [val, flags]
        end
      end
    end
  end

end
