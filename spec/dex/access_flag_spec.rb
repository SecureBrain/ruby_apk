require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Android::Dex::AccessFlag do
  let(:flag) { 0x01 }
  subject { Android::Dex::AccessFlag.new(flag) }
  its(:flag) { should eq flag }
end

describe Android::Dex::ClassAccessFlag do
  let(:accessor) { Android::Dex::ClassAccessFlag.new(flags) }

  subject { accessor.to_s }
  context 'flags are 0x19(public static final)' do
    let(:flags) { 0x19 }
    it { should eq 'public static final' }
  end
  context 'flags are 0xc0(volatile transient)' do
    let(:flags) { 0xc0 }
    it { should eq 'volatile transient' }
  end
  context 'flags are 0x22(private synchronized)' do
    let(:flags) { 0x22 }
    it { should eq 'private synchronized' }
  end
end

describe Android::Dex::MethodAccessFlag do
  let(:accessor) { Android::Dex::MethodAccessFlag.new(flags) }
  subject { accessor.to_s }
  context 'flags are 0x19(public static final)' do
    let(:flags) { 0x19 }
    it { should eq 'public static final' }
  end
  context 'flags are 0xc0(bridge varargs)' do
    let(:flags) { 0xc0 }
    it { should eq 'bridge varargs' }
  end
  context 'flags are 0x22(private synchronized)' do
    let(:flags) { 0x22 }
    it { should eq 'private synchronized' }
  end
end
