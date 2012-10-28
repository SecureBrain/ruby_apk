module Android
  class Dex
    class << self
      # parse uleb128(unsigned integer) data
      # @param [String] data target byte data
      # @param [Integer] offset 
      # @return [Integer, Integer] parsed value and parsed byte length
      # @see http://en.wikipedia.org/wiki/LEB128
      def uleb128(data, offset=0)
        result = 0
        shift = 0
        d = data[offset...data.size]
        (0..4).each do |i|
          byte = d.getbyte(i)
          result |= ((byte & 0x7f) << shift)
          return result, i+1 if ((byte & 0x80) == 0)
          shift += 7
        end
      end
      # parse uleb128 + 1 data
      # @param [String] data target byte data
      # @param [Integer] offset 
      # @return [Integer, Integer] parsed value and parsed byte length
      def uleb128p1(data, offset=0)
        ret, len = self.uleb128(data, offset)
        return (ret - 1), len
      end
      # parse sleb128(signed integer) data
      # @param [String] data target byte data
      # @param [Integer] offset 
      # @return [Integer, Integer] parsed value and parsed byte length
      def sleb128(data, offset=0)
        result  = 0
        shift = 0
        d = data[offset...data.size]
        (0..4).each do |i|
          byte  = d.getbyte(i)
          result  |=((byte & 0x7F) << shift)
          return (0 == (byte & 0x40) ? result : result - (1 << (shift+7))), i+1 if ((byte & 0x80) == 0)
          shift += 7
        end
      end
    end
  end
end
