require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Android::Manifest do
  describe Android::Manifest::Component do
    describe "self.valid?" do
      let(:elem) { REXML::Element.new('service') }
      subject { Android::Manifest::Component.valid?(elem) }
      context "with valid component element" do
        it { should be_true }
      end
      context "with invalid component element" do
        let(:elem) { REXML::Element.new('invalid-name') }
        it { should be_false }
      end
      context "when some exception occurs in REXML::Element object" do
        let(:elem) {
          elem = stub(REXML::Element)
          elem.stub(:name).and_raise(StandardError)
          elem
        }
        it { should be_false }
      end
    end
    describe '#metas' do
      subject { Android::Manifest::Component.new(elem).metas }
      context 'with valid component element has 2 meta elements' do
        let(:elem) { 
          elem = REXML::Element.new('service') 
          elem << REXML::Element.new('meta-data')
          elem << REXML::Element.new('meta-data')
          elem
        }
        it { should have(2).item }
      end
    end
    describe '#elem' do
      subject { Android::Manifest::Component.new(elem).elem }
      let(:elem) { REXML::Element.new('service') }
      it { should eq elem }
    end

    describe Android::Manifest::Meta do
      let(:elem) do
        attrs = { 'name' => 'meta name', 'resource' => 'res', 'value' => 'val' }
        elem = stub(REXML::Element, :attributes => attrs)
        elem
      end
      subject { Android::Manifest::Meta.new(elem) }
      its(:name) { should eq 'meta name' }
      its(:resource) { should eq 'res' }
      its(:value) { should eq 'val' }
    end
  end

  describe Android::Manifest::IntentFilter do
    describe '.parse' do
      subject { Android::Manifest::IntentFilter.parse(elem) }
      context 'assings "action" element' do
        let(:elem) { REXML::Element.new('action') }
        it { should be_instance_of Android::Manifest::IntentFilter::Action }
      end
      context 'assings "category" element' do
        let(:elem) { REXML::Element.new('category') }
        it { should be_instance_of Android::Manifest::IntentFilter::Category }
      end
      context 'assings "data" element' do
        let(:elem) { REXML::Element.new('data') }
        it { should be_instance_of Android::Manifest::IntentFilter::Data }
      end
      context 'assings unknown element' do
        let(:elem) { REXML::Element.new('unknown') }
        it { should be_nil }
      end
    end
  end

  context "with stub AXMLParser" do
    let(:dummy_xml) {
      xml = REXML::Document.new
      xml << REXML::Element.new('manifest')
    }
    let(:manifest) { Android::Manifest.new('mock data') }

    before do
      parser = stub(Android::AXMLParser, :parse => dummy_xml) 
      Android::AXMLParser.stub(:new).and_return(parser)
    end

    describe "#use_parmissions" do
      subject { manifest.use_permissions }
      context "with valid 3 parmission elements" do
        before do
          3.times do |i|
            elem = REXML::Element.new("uses-permission")
            elem.add_attribute 'name', "permission#{i}"
            dummy_xml.root << elem
          end
        end
        it { subject.should have(3).items }
        it "should have permissions" do
          subject.should include("permission0")
          subject.should include("permission1")
          subject.should include("permission2")
        end
      end
      context "with no parmissions" do
        it { should be_empty }
      end
    end

    describe "#components" do
      subject { manifest.components }
      context "with valid parmission element" do
        before do
          app = REXML::Element.new('application')
          activity = REXML::Element.new('activity')
          app << activity
          dummy_xml.root << app
        end
        it "should have components" do
          subject.should have(1).items
        end
        it "should returns Component object" do
          subject[0].should be_kind_of Android::Manifest::Component
        end
      end
      context "with no components" do
        it { should be_empty }
      end
      context 'with text element in intent-filter element. (issue #3)' do 
        before do
          app = REXML::Element.new('application')
          activity = REXML::Element.new('activity')
          intent_filter = REXML::Element.new('intent-filter')
          text = REXML::Text.new('sample')

          intent_filter << text
          activity << intent_filter
          app << activity
          dummy_xml.root << app
        end
        it "should have components" do
          subject.should have(1).items
        end
        it { expect { subject }.to_not raise_error }
      end
    end
  end

  context "with real sample_AndroidManifest.xml data" do
    let(:bin_xml_path){ File.expand_path(File.dirname(__FILE__) + '/data/sample_AndroidManifest.xml') }
    let(:bin_xml){ File.open(bin_xml_path, 'rb') {|f| f.read } }
    let(:manifest){ Android::Manifest.new(bin_xml) }

    describe "#components" do
      subject { manifest.components }
      it { should be_kind_of Array }
      it { subject[0].should be_kind_of Android::Manifest::Component }
    end
    describe "#package_name" do
      subject { manifest.package_name }
      it { should == "example.app.sample" }
    end
    describe "#version_code" do
      subject { manifest.version_code}
      it { should == 101 }
    end
    describe "#version_name" do
      subject { manifest.version_name}
      it { should == "1.0.1-malware2" }
    end
    describe "#min_sdk_ver" do
      subject { manifest.min_sdk_ver}
      it { should == 10 }
    end
    describe "#label" do
      subject { manifest.label }
      it { should == "@0x7f040001" }

      context "with real apk file" do
        let(:tmp_path){ File.expand_path(File.dirname(__FILE__) + '/data/sample.apk') }
        let(:apk) { Android::Apk.new(tmp_path) }
        let(:manifest){ apk.manifest }
        subject { manifest.label }
        it { should eq 'Sample' }
        context 'when assign lang code' do
          subject { manifest.label('ja') }
          it { should eq 'Sample' }
        end
      end
    end
    describe "#doc" do
      subject { manifest.doc }
      it { should be_instance_of REXML::Document }
    end
    describe "#to_xml" do
      let(:raw_xml){ str = <<EOS
<manifest xmlns:android='http://schemas.android.com/apk/res/android' android:versionCode='101' android:versionName='1.0.1-malware2' package='example.app.sample'>
    <uses-sdk android:minSdkVersion='10'/>
    <uses-permission android:name='android.permission.INTERNET'/>
    <uses-permission android:name='android.permission.WRITE_EXTERNAL_STORAGE'/>
    <application android:label='@0x7f040001' android:icon='@0x7f020000' android:debuggable='true'>
        <activity android:label='@0x7f040001' android:name='example.app.sample.SampleActivity'>
            <intent-filter>
                <action android:name='android.intent.action.MAIN'/>
                <category android:name='android.intent.category.LAUNCHER'/>
            </intent-filter>
        </activity>
    </application>
</manifest>
EOS
        str.strip
      }

      subject { manifest.to_xml }
      it "should return correct xml string" do
        subject.should == raw_xml
      end
    end
  end
end
