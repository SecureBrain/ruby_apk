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

    context 'with str_resources.arsc data' do
      let(:res_data) { File.read(File.expand_path(File.dirname(__FILE__) + '/data/str_resources.arsc')) }
      subject { resource }
      describe 'about drawable resource' do
        it 'hoge' do
          table = resource.packages.first[1]
          p table
          table.type_strings.each_with_index do |type, id|
            puts "[0x#{(id+1).to_s(16)}] #{type}"
          end
          puts "readable id:" + table.res_readable_id('@0x7f020000')
        end
      end
    end
    context 'with str_resources.arsc data' do
      let(:res_data) { File.read(File.expand_path(File.dirname(__FILE__) + '/data/str_resources.arsc')) }
      subject { resource }
      describe '#packages' do
        subject {resource.packages}
        it { should be_instance_of Hash}
        it { subject.size.should eq 1 }
      end
      describe 'ResTablePackage' do
        subject { resource.packages.first[1] }
        it { subject.type(1).should eq 'attr' }
        it { subject.type(4).should eq 'string' }
        it { subject.name.should eq 'com.example.sample.ruby_apk' }
      end
      describe '#find' do
        it '@0x7f040000 should return "sample.ruby_apk"' do
          subject.find('@0x7f040000').should eq 'sample application'
        end
        it '@string/app_name should return "sample.ruby_apk"' do
          subject.find('@string/app_name').should eq 'sample application'
        end
        it '@string/hello_world should return "Hello world!"' do
          subject.find('@string/hello_world').should eq 'Hello world!'
        end
        it '@string/app_name should return "sample.ruby_apk"' do
          subject.find('@string/app_name').should eq 'sample application'
        end
        it '@string/app_name with {:lang => "ja"} should return "サンプルアプリ"' do
          subject.find('@string/app_name', :lang => 'ja').should eq 'サンプルアプリ'
        end
        it '@string/hello_world with {:lang => "ja"} should return nil' do
          subject.find('@string/hello_world', :lang => 'ja').should be_nil
        end
        context 'assigns not exist string resource id' do
          it {  expect {subject.find('@string/not_exist') }.to raise_error Android::NotFoundError }
          it {  expect {subject.find('@0x7f040033') }.to raise_error Android::NotFoundError }
        end
        context 'assigns not string resource id' do
          it { subject.find('@layout/activity_main').should be_nil }
        end
        context 'assigns invalid format id' do
          it '"@xxyyxxyy" should raise ArgumentError' do
            expect{ subject.find('@xxyyxxyy') }.to raise_error(ArgumentError)
          end
          it '"@0xff112233445566" should raise ArgumentError' do
            expect{ subject.find('@0xff112233445566') }.to raise_error(ArgumentError) 
          end
        end
      end
      describe '#res_readable_id' do
        it { subject.res_readable_id('@0x7f040000').should eq '@string/app_name' }
        context 'assigns invalid type' do
          it { expect{subject.res_readable_id('@0x7f0f0000')}.to raise_error Android::NotFoundError }
        end
        context 'assigns invalid key' do
          it { expect{subject.res_readable_id('@0x7f040033')}.to raise_error Android::NotFoundError }
        end
      end
      describe '#res_hex_id' do
        it { subject.res_hex_id('@string/app_name').should eq '@0x7f040000' }
        context 'assigns invalid type' do
          it { expect{subject.res_readable_id('@not_exist/xxxx')}.to raise_error Android::NotFoundError }
        end
        context 'assigns invalid key' do
          it { expect{subject.res_readable_id('@string/not_exist')}.to raise_error Android::NotFoundError }
        end
      end
    end
  end
end
