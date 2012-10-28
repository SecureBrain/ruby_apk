require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

shared_context 'with sample_classes.dex', with: :sample_dex do
  let(:dex_path){ File.expand_path(File.dirname(__FILE__) + '/../data/sample_classes.dex') }
  let(:dex_bin){ File.open(dex_path, 'rb') {|f| f.read } }
  let(:dex){ Android::Dex.new(dex_bin) }
  let(:last_class) { dex.classes.last }
end
describe Android::Dex::ClassInfo do
  include_context 'with sample_classes.dex'
  context 'about the last class in Dex#classes with sample_classes.dex' do
    let(:last_class) { dex.classes.last }
    its(:name){ should eq 'Lexample/app/sample/SampleCode;' }
    its(:access_flags){ should be_instance_of Android::Dex::ClassAccessFlag }
    its(:super_class){ should eq 'Ljava/lang/Object;' }
    its(:class_data){ should be_instance_of Android::Dex::DexObject::ClassDataItem }
    its(:class_def){ should be_instance_of Android::Dex::DexObject::ClassDefItem }
    its(:definition) { should eq 'public class Lexample/app/sample/SampleCode; extends Ljava/lang/Object;' }

    subject { last_class }
    describe '#static_fields' do
      subject { last_class.static_fields }
      it { should have(1).item }
      specify { subject[0].should be_instance_of Android::Dex::FieldInfo }
    end
    describe '#instance_fields' do
      subject { last_class.instance_fields }
      it { should have(1).item }
      specify { subject[0].should be_instance_of Android::Dex::FieldInfo }
    end
    describe '#direct_methods' do
      subject { last_class.direct_methods }
      it { should have(3).items }
      specify { subject[0].should be_instance_of Android::Dex::MethodInfo }
    end
    describe '#virtual_methods' do
      subject { last_class.virtual_methods }
      it { should have(18).items }
      specify { subject[0].should be_instance_of Android::Dex::MethodInfo }
    end
  end
  context 'when class_data_item is nil' do
    let(:mock_cls_def) {
      s = double(Android::Dex::DexObject::ClassDefItem)
      s.stub(:'[]').with(anything()).and_return(0)
      s.stub(:class_data_item).and_return(nil)
      s
    }
    let(:class_info) { Android::Dex::ClassInfo.new(mock_cls_def, nil) }
    describe '#static_fields' do
      subject { class_info.static_fields }
      it { should be_kind_of Array }
      it { should be_empty }
    end
    describe '#instance_fields' do
      subject { class_info.instance_fields }
      it { should be_kind_of Array }
      it { should be_empty }
    end
    describe '#direct_methods' do
      subject { class_info.direct_methods }
      it { should be_kind_of Array }
      it { should be_empty }
    end
    describe '#virtual_methods' do
      subject { class_info.virtual_methods }
      it { should be_kind_of Array }
      it { should be_empty }
    end
  end
end

describe Android::Dex::FieldInfo do
  include_context 'with sample_classes.dex'
  context 'about the first static field of the last class with sample_classes.dex'do
    let(:first_static_field) { last_class.static_fields.first }
    subject { first_static_field }
    its(:name) { should eq 'TAG' }
    its(:type) { should eq 'Ljava/lang/String;' }
    describe '#access_flags' do
      subject { first_static_field.access_flags }
      it { should be_instance_of Android::Dex::ClassAccessFlag }
      specify { subject.to_s.should eq 'private static final' }
    end
    describe '#definition' do
      subject { first_static_field.definition }
      it { should eq 'private static final Ljava/lang/String; TAG' }
    end
  end
end

describe Android::Dex::MethodInfo do
  include_context 'with sample_classes.dex'
  context 'about the first direct method of the last class' do
    let(:first_direct_method) { last_class.direct_methods.first }
    subject { first_direct_method }
    its(:name) { should eq '<init>' }
  end
  context 'about the first virtual method of the last class' do
    let(:first_virtual_method) { last_class.virtual_methods.first }
    subject { first_virtual_method }
    its(:name) { should eq 'processDoWhile' }
    its(:code_item) { should be_instance_of Android::Dex::DexObject::CodeItem }
    describe '#parameters' do
      subject { first_virtual_method.parameters }
      it { should have(1).item }
      it { should include('int') }
    end
  end
  context 'about the 12th virtual method(processTryCatch) of the last class' do
    let(:a_virtual_method) { last_class.virtual_methods[12]}
    subject { a_virtual_method }
    its(:name) { should eq 'processTryCatch' }
    describe '#code_item' do
      subject { a_virtual_method.code_item }
      it { should be_instance_of Android::Dex::DexObject::CodeItem }
      its(:debug_info_item) { should be_instance_of Android::Dex::DexObject::DebugInfoItem }
    end
  end
end

