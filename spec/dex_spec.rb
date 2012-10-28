require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Android::Dex do
  let(:dex_path){ File.expand_path(File.dirname(__FILE__) + '/data/sample_classes.dex') }
  let(:dex_bin){ File.open(dex_path, 'rb') {|f| f.read } }
  let(:dex){ Android::Dex.new(dex_bin) }


  describe '#initialize' do
    subject { dex }
    context 'with valid dex data' do
      it { should be_instance_of(Android::Dex) }
    end
    context 'with nil data' do
      let(:dex_bin) { nil }
      specify { expect{ subject }.to raise_error  }
    end
  end

  describe '#data' do
    subject { dex.data }
    it { should be_instance_of String }
    specify { subject.encoding.should eq Encoding::ASCII_8BIT }
  end

  describe '#strings' do
    let(:num_str) { dex.header[:string_ids_size] }
    subject { dex.strings }
    it { should be_instance_of Array }
    it 'should have string_ids_size items' do
      should have(num_str).items
    end
    it "should be the particular string(depends on sample_classes.dex)" do
      subject[0].should eq "%d"
    end
    it "should be the particular string(depends on sample_classes.dex)" do
      subject[1].should eq "<init>"
    end
    it "should be the particular string(depends on sample_classes.dex)" do
      subject[2].should eq "BuildConfig.java"
    end
  end
    describe '#inspect' do
      subject { dex.inspect }
      it { should match(/\A<Android::Dex.*>\Z/m) }
    end

  describe '#classes' do
    subject { dex.classes }
    let(:num_classes) { dex.header[:class_defs_size] }
    it{ should be_instance_of Array }
    it{ should have(num_classes).items }
    describe 'first item' do
      subject { dex.classes.first }
      it{ should be_instance_of Android::Dex::ClassInfo }
    end
  end
end

