# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Android::AXMLParser do
  let(:bin_xml_path){ File.expand_path(File.dirname(__FILE__) + '/data/sample_AndroidManifest.xml') }
  let(:bin_xml){ File.open(bin_xml_path, 'rb') {|f| f.read } }
  let(:axmlparser){ Android::AXMLParser.new(bin_xml) }

  describe "#parse" do

    subject { axmlparser.parse }
    context 'with sample_AndroidManifest.xml' do
      it { should be_instance_of(REXML::Document) }
      specify 'root element should be <manifest> element' do
        subject.root.name.should eq 'manifest'
      end
      specify 'should have 2 <uses-permission> elements' do
        subject.get_elements('/manifest/uses-permission').should have(2).items
      end
    end

    context 'with nil data as binary xml' do
      let(:bin_xml) { nil }
      specify { expect{ subject }.to raise_error }
    end

  end

  describe "#strings" do
    context 'with sample_AndroidManifest.xml' do
      subject { axmlparser.strings }
      before do
        axmlparser.parse
      end
      it { should be_instance_of(Array) }

      # ugh!! the below test cases depend on sample_AndroidManifest.xml
      it { should have(26).items} # in sample manifest.
      it { should include("versionCode") }
      it { should include("versionName") }
      it { should include("minSdkVersion") }
      it { should include("package") }
      it { should include("manifest") }
    end
  end
end
