require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Android::Layout do
  context 'with real apk sample file' do
    let(:apk_path){ File.expand_path(File.dirname(__FILE__) + '/data/sample.apk') }
    let(:apk){ Android::Apk.new(apk_path) }
    let(:layouts) { apk.layouts }
    subject { layouts }
    it { should be_a Hash }
    it { should have_key "res/layout/main.xml" }
    it { should have(1).item }
    context 'about first item' do
      subject { layouts['res/layout/main.xml'] }
      it { should be_a Android::Layout }
      describe '#path' do
        it { subject.path.should eq 'res/layout/main.xml' }
      end
      describe '#doc' do
        it { subject.doc.should be_a REXML::Document }
      end
      describe '#to_xml' do
        it { subject.to_xml.should be_a String }
      end
    end
  end
end

