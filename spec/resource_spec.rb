# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Android::Resource do
  let(:res_data) { File.read(res_path) }
  let(:resource) { Android::Resource.new(res_data) }

  shared_examples_for 'a valid Android::Resource' do
    subject { resource }
    describe '#initialize' do
      context 'assigns resources.arsc data' do
        it { should be_instance_of Android::Resource }
      end
    end
    its(:package_count) {should eq 1 }
    describe '#strings' do
      subject { resource.strings }
      it { should have(7).items } # depends on sample_resources.arsc
      it { should include 'Sample' }
      it { should include 'Hello World, SampleActivity!' }
      it { should include '日本語リソース' }
    end
  end
  context 'with sample_resources.arsc data' do
    let(:res_path) { File.expand_path(File.dirname(__FILE__) + '/data/sample_resources.arsc') }
    it_behaves_like 'a valid Android::Resource'

  end
  context 'with sample_resources_utf16.arsc data' do
    let(:res_path) { File.expand_path(File.dirname(__FILE__) + '/data/sample_resources_utf16.arsc') }
    it_behaves_like 'a valid Android::Resource'
  end

  describe Android::Resource::ChunkHeader do
    shared_examples_for 'a chunk header' do
      its(:type) { should eq 20 }
      its(:header_size) { should eq 244 }
      its(:size) { should eq 1000 }
    end
    subject { Android::Resource::ChunkHeader.new(data, offset) }
    context 'with no offset' do
      let(:data) { "\x14\x00\xF4\x00\xE8\x03\x00\x00" } # [20, 244, 1000].pack('vvV')
      let(:offset) { 0 }
      it_behaves_like 'a chunk header'
    end
    context 'with 10byte offset' do
      let(:data) { "\x00"*10 + "\x14\x00\xF4\x00\xE8\x03\x00\x00" } # [20, 244, 1000].pack('vvV')
      let(:offset) { 10 }
      it_behaves_like 'a chunk header'
    end
  end

  describe Android::Resource::ResStringPool do
    describe '.utf8_len' do
      subject { Android::Resource::ResStringPool.utf8_len(data) }
      context 'assigns 0x7F' do
        let(:data) { "\x7f" }
        it { should eq [0x7f, 1] }
      end
      context 'assigns x81x01' do
        let(:data) { "\x81\x01" }
        it { should eq [0x0101, 2] }
      end
      context 'assigns xffxff' do
        let(:data) { "\xff\xff" }
        it { should eq [0x7fff, 2] }
      end
    end
    describe '#utf16_len' do
      subject { Android::Resource::ResStringPool.utf16_len(data) }
      context 'assigns x7fff' do
        let(:data) { "\xff\x7f" }
        it { should eq [0x7fff, 2] }
      end
      context 'assigns x8001,x0001' do
        let(:data) { "\x01\x80\x01\x00" }
        it { should eq [0x10001, 4] }
      end
      context 'assigns xffff,xffff' do
        let(:data) { "\xff\xff\xff\xff" }
        it 'should eq 0x7fff 0xffff' do
          should eq [0x7fffffff, 4] 
        end
      end
    end
  end
end
