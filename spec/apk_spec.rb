require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'tempfile'
require 'zip'
require 'digest/sha1'
require 'digest/sha2'
require 'digest/md5'

class TempApk
  attr_reader :path
  def initialize
    @tmp = Tempfile.open('apk_spec')
    @path = @tmp.path
    @tmp.close! # delete file
    append("AndroidManifest.xml", "hogehoge")
    append("resources.arsc", "hogehoge")
  end
  def destroy!
    File.unlink(@path) if File.exist? @path
  end
  def append(entry_name, data)
    Zip::File.open(@path, Zip::File::CREATE) { |zip|
      zip.get_output_stream(entry_name) {|f| f.write data }
    }
  end
  def remove(entry_name)
    Zip::File.open(@path, Zip::File::CREATE) { |zip|
      zip.remove(entry_name)
    }
  end
end

describe Android::Apk do
  before do
    $stderr.reopen('/dev/null','w')
  end
  let(:tmp_apk) { TempApk.new }
  let(:tmp_path) { tmp_apk.path }
  let(:apk) { Android::Apk.new(tmp_path) }
  subject { apk }

  after do
    tmp_apk.destroy!
  end

  describe "#initialize" do
    let(:path) { tmp_path }
    subject { Android::Apk.new(path) }
    context "with not exist path" do
      let(:path) { "not exist path" }
      it { expect{ subject }.to raise_error Android::NotFoundError }
    end
    context "with not zip file path" do
      let(:path) { __FILE__ } # not zip file
      it { expect{ subject }.to raise_error Android::NotApkFileError }
    end
    context "with zip(and non apk) file" do
      before do
        tmp_apk.append('hoge.txt', 'hogehoge')
        tmp_apk.remove('AndroidManifest.xml')
      end
      it { expect{ subject }.to raise_error Android::NotApkFileError }
    end
    context "with zip includes AndroidManifest.xml" do
      it { should be_a_instance_of Android::Apk }
    end
  end

  describe "#path" do
    subject { apk.path }
    it "should equals initialized path" do
      should == tmp_path
    end
  end

  describe "#manifest" do
    subject { apk.manifest }

    context "when Manifest parse is succeeded." do
      let(:mock_mani) { mock(Android::Manifest) }

      before do
      end
      it "should return manifest object" do
        Android::Manifest.should_receive(:new).and_return(mock_mani)
        subject.should == mock_mani
      end
    end

    context "when Manifest parse is failed" do
      it 'should return nil' do
        Android::Manifest.should_receive(:new).and_raise(Android::AXMLParser::ReadError)
        subject.should be_nil
      end
    end
  end

  describe "#dex" do
    let(:mock_dex) { mock(Android::Dex) }
    subject { apk.dex }
    context "when there is no dex file" do
      it { should be_nil }
    end
    context "when invalid dex file" do
      before do
        tmp_apk.append("classes.dex", "invalid dex")
      end
      it { should be_nil }
    end
    context "with mock classes.dex file" do
      before do
        tmp_apk.append("classes.dex", "mock data")
      end
      it "should return mock value" do
        Android::Dex.should_receive(:new).with("mock data").and_return(mock_dex)
        subject.should == mock_dex
      end
    end
    context "with real classes.dex file" do
      before do
        dex_path = File.expand_path(File.dirname(__FILE__) + '/data/sample_classes.dex')
        tmp_apk.append("classes.dex", File.open(dex_path, "rb") {|f| f.read })
      end
      it { should be_instance_of Android::Dex }
    end
  end

  its(:bindata) { should be_instance_of String }
  describe '#bindata' do
    specify 'encoding should be ASCII-8BIT' do
      subject.bindata.encoding.should eq Encoding::ASCII_8BIT
    end
  end

  describe '#resource' do
    let(:mock_rsc) { mock(Android::Resource) }
    subject { apk.resource }
    it "should return manifest object" do
      Android::Resource.should_receive(:new).and_return(mock_rsc)
      subject.should == mock_rsc
    end
  end

  describe "#size" do
    subject { apk.size }
    it "should return apk file size" do
      should == File.size(tmp_path)
    end
  end

  describe "#digest" do
    let(:data) { File.open(tmp_apk.path, 'rb'){|f| f.read } }
    subject { apk.digest(type) }
    context "when type is sha1" do
      let(:type) { :sha1 }
      it "should return sha1 digest" do
        should eq Digest::SHA1.hexdigest(data)
      end
    end
    context "when type is sha256" do
      let(:type) { :sha256 }
      it "should return sha256 digest" do
        should == Digest::SHA256.hexdigest(data)
      end
    end
    context "when type is md5" do
      let(:type) { :md5 }
      it "should return md5 digest" do
        should == Digest::MD5.hexdigest(data)
      end
    end
    context "when type is unkown symbol" do
      let(:type) { :unknown }
      it do
        expect { subject }.to raise_error(ArgumentError)
      end
    end
    context "when type is not symbol(String: 'sha1')" do
      let(:type) { 'sha1' }
      it { expect { subject }.to raise_error(ArgumentError) }
    end
  end

  describe '#time' do
    subject { apk.time }
    it { should be_kind_of Time }
  end

  describe "#each_file" do
    before do
      tmp_apk.append("hoge.txt", "aaaaaaa")
    end
    it { expect { |b| apk.each_file(&b) }.to yield_successive_args(Array, Array, Array) }
    let(:each_file_result ) {
      result = []
      apk.each_file do |name, data|
        result << [name, data]
      end
      result
    }

    it "should invoke block with all file" do
      each_file_result.should have(3).items
      each_file_result.should include(['AndroidManifest.xml', 'hogehoge'])
      each_file_result.should include(['hoge.txt','aaaaaaa'])
    end
  end

  describe '#file' do
    let(:data) { 'aaaaaaaaaaaaaaaaaaaaaaaaaaa' }
    let(:path) { 'hoge.txt' }
    subject { apk.file(path) }

    before do
      tmp_apk.append('hoge.txt', data)
    end
    context 'assigns exist path' do
      it 'should equal file data' do
        should eq data
      end
    end
    context 'assigns not exist path' do
      let(:path) { 'not_exist_path.txt' }
      it { expect { subject }.to raise_error(Android::NotFoundError) }
    end
  end

  describe '#each_entry' do
    before do
      tmp_apk.append("hoge.txt", "aaaaaaa")
    end
    it { expect { |b| apk.each_entry(&b) }.to yield_successive_args(Zip::Entry, Zip::Entry, Zip::Entry) }
  end

  describe '#entry' do
    subject { apk.entry(entry_name) }
    context 'assigns exist entry' do
      let(:entry_name) { 'AndroidManifest.xml' }
      it { should be_instance_of Zip::Entry }
    end
    context 'assigns not exist entry name' do
      let(:entry_name) { 'not_exist_path' }
      it { expect{ subject }.to raise_error(Android::NotFoundError) }
    end
  end

  describe "#find" do
    before do
      tmp_apk.append("hoge.txt", "aaaaaaa")
    end
    it "should return matched array" do
      array = apk.find do |name, data|
        name == "hoge.txt"
      end
      array.should be_instance_of Array
      array.should have(1).item
      array[0] == "hoge.txt" # returns filename
    end
    context "when no entry is matched" do
      it "should return emtpy array" do
        array = apk.find do |name, dota|
          false # nothing matched
        end
        array.should be_instance_of Array
        array.should be_empty
      end
    end
  end

  describe "#icon" do
    context "with real apk file" do
      let(:tmp_path){ File.expand_path(File.dirname(__FILE__) + '/data/sample.apk') }
      subject { apk.icon }
      it { should be_a Hash }
      it { should have(3).items }
      it { subject.keys.should =~ ["res/drawable-hdpi/ic_launcher.png", "res/drawable-ldpi/ic_launcher.png", "res/drawable-mdpi/ic_launcher.png"]
 }
    end
  end

  describe '#signs' do
    context 'with sampe apk file' do
      let(:tmp_path){ File.expand_path(File.dirname(__FILE__) + '/data/sample.apk') }
      subject { apk.signs }
      it { should be_a Hash }
      it { should have(1).item }
      it { should have_key('META-INF/CERT.RSA') }
      it { subject['META-INF/CERT.RSA'].should be_a OpenSSL::PKCS7 }
    end
  end

  describe '#certficates' do
    context 'with sampe apk file' do
      let(:tmp_path){ File.expand_path(File.dirname(__FILE__) + '/data/sample.apk') }
      subject { apk.certificates }
      it { should be_a Hash }
      it { should have(1).item }
      it { should have_key('META-INF/CERT.RSA') }
      it { subject['META-INF/CERT.RSA'].should be_a OpenSSL::X509::Certificate }
    end
  end
end
