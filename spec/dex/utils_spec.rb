require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Android::Dex do

  describe ".uleb128" do
    # @see http://en.wikipedia.org/wiki/LEB128
    it "[0x00] should be 0" do
      Android::Dex.uleb128("\x00").should == [0,1]
    end
    it "[0x01] should be 1" do
      Android::Dex.uleb128("\x01").should == [1,1]
    end
    it "[0x7f] should be 127" do
      Android::Dex.uleb128("\x7f").should == [127,1]
    end
    it "[0x80,0x7f] should be 16256" do
      Android::Dex.uleb128("\x80\x7f").should == [16256,2]
    end
    it "[0xe5,0x8e,0x26] should be 624485" do
      Android::Dex.uleb128("\xe5\x8e\x26").should == [624485,3]
    end
  end

  describe ".uleb128p1" do
    it "[0x00] should be -1" do
      Android::Dex.uleb128p1("\x00").should == [-1,1]
    end
    it "[0x01] should be 0" do
      Android::Dex.uleb128p1("\x01").should == [0,1]
    end
    it "[0x7f] should be 126" do
      Android::Dex.uleb128p1("\x7f").should == [126,1]
    end
    it "[0x80,0x7f] should be 16255" do
      Android::Dex.uleb128p1("\x80\x7f").should == [16255,2]
    end
    it "[0xe5,0x8e,0x26] should be 624485" do
      Android::Dex.uleb128("\xe5\x8e\x26").should == [624485,3]
    end
  end
  describe '.sleb128' do
    it "[0x00] should be 0" do
      Android::Dex.sleb128("\x00").should == [0,1]
    end
    it "[0x01] should be 1" do
      Android::Dex.sleb128("\x01").should == [1,1]
    end
    it "[0x7f] should be -1" do
      Android::Dex.sleb128("\x7f").should == [-1,1]
    end
    it "[0x80,0x7f] should be 127" do
      Android::Dex.sleb128("\x80\x7f").should == [-128,2]
    end
  end
end

