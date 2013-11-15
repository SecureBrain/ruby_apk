require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Android::Dex do
  describe Android::Dex::DexObject::Header do
    let(:header_sample) {
      sample = 
        "\x64\x65\x78\x0A\x30\x33\x35\x00\x3F\x14\x98\x2C\x25\x77\x9B\x8D" +
        "\x7C\xF0\x0B\xFA\x4D\x7B\x03\xAD\x4C\x15\xBC\x31\x4F\xD3\x4B\x71" +
        "\x58\x18\x00\x00\x70\x00\x00\x00\x78\x56\x34\x12\x00\x00\x00\x00" +
        "\x00\x00\x00\x00\x88\x17\x00\x00\x7A\x00\x00\x00\x70\x00\x00\x00" +
        "\x23\x00\x00\x00\x58\x02\x00\x00\x0E\x00\x00\x00\xE4\x02\x00\x00" +
        "\x10\x00\x00\x00\x8C\x03\x00\x00\x2C\x00\x00\x00\x0C\x04\x00\x00" +
        "\x0A\x00\x00\x00\x6C\x05\x00\x00\xAC\x11\x00\x00\xAC\x06\x00\x00"
      sample.force_encoding(Encoding::ASCII_8BIT)
    }
    let(:header) { Android::Dex::DexObject::Header.new(header_sample) }
    describe "#symbols" do
      subject { header.symbols }
      it { should be_kind_of(Array) }
      it { should have(23).items }
      it { should include(:magic) }
      it { should include(:checksum) }
      it { should include(:signature) }
      it { should include(:file_size) }
      it { should include(:header_size) }
      it { should include(:endian_tag) }
      it { should include(:link_size) }
      it { should include(:link_off) }
      it { should include(:map_off) }
      it { should include(:string_ids_size) }
      it { should include(:string_ids_off) }
      it { should include(:type_ids_size) }
      it { should include(:type_ids_off) }
      it { should include(:proto_ids_size) }
      it { should include(:proto_ids_off) }
      it { should include(:field_ids_size) }
      it { should include(:field_ids_off) }
      it { should include(:method_ids_size) }
      it { should include(:method_ids_off) }
      it { should include(:class_defs_size) }
      it { should include(:class_defs_off) }
      it { should include(:data_size) }
      it { should include(:data_off) }
    end

    describe "#[]" do
      subject { header }
      it ':magic should be "dex\n035\0"' do 
        subject[:magic].should ==  "dex\n035\0"
      end
      it ":checksum should be 748164159(this value depends on sample_classes.dex)" do
        subject[:checksum].should == 748164159
      end
      it ":signature should be 20byte string" do
        subject[:signature].should be_kind_of String
        subject[:signature].length == 20
      end
      it ":file_size should be classes.dex file size" do
        subject[:file_size].should == 6232
      end
      it ":header_size should be 0x70" do
        subject[:header_size].should == 0x70
      end
      it "should have integer params" do
        subject[:header_size].should == 0x70
      end
      context "with int symbols" do
        before do
          @params = [
            :link_size,
            :link_off,
            :map_off,
            :string_ids_size,
            :string_ids_off,
            :type_ids_size,
            :type_ids_off,
            :proto_ids_size,
            :proto_ids_off,
            :field_ids_size,
            :field_ids_off,
            :method_ids_size,
            :method_ids_off,
            :class_defs_size,
            :class_defs_off,
            :data_size,
            :data_off,
          ]
        end
        it "should have integer value" do
          @params.each do |sym|
            subject[sym].should be_kind_of Integer
          end
        end
      end
      context "with unkown params" do
        it { subject[:unkown].should be_nil }
      end
    end

    describe "#inspect" do
      subject { header.inspect }
      it { should match(/\A<Android::Dex::DexObject::Header.*>\Z/m) }
    end
  end

  describe Android::Dex::DexObject::StringDataItem do
    let(:string_data_item_sample) {
      sample = "\x0b\x61\x62\x63\xc0\x80\xc8\x85\xe3\x81\x82\xe3\x81\x84\xe3\x81\x86\xed\xa0\x81\xed\xb0\x80\xc0\x80"
      sample.force_encoding(Encoding::ASCII_8BIT)
    }
    let(:string_data_item) { Android::Dex::DexObject::StringDataItem.new(string_data_item_sample, 0) }
    describe "#to_s" do
      subject { string_data_item.to_s }
      it { should == "abc\u{205}\u{3042}\u{3044}\u{3046}\u{10400}" }
    end
  end

end
