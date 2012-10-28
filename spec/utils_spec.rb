require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Android::Utils do
  let(:sample_apk_path) { File.expand_path(File.dirname(__FILE__) + '/data/sample.apk') }
  let(:sample_dex_path) { File.expand_path(File.dirname(__FILE__) + '/data/sample_classes.dex') }
  describe '.apk?' do
    subject { Android::Utils.apk?(apk_path) }

    context 'assigns apk file path' do
      let(:apk_path) { sample_apk_path }
      it { should be_true }
    end
    context 'assigns nil' do
      let(:apk_path) { nil }
      it { should be_false }
    end
    context 'assigns not exist path' do
      let(:apk_path) { 'hogehoge' }
      it { should be_false }
    end
    context 'assigns not apk file path' do
      let(:apk_path) { __FILE__ }
      it { should be_false }
    end
  end

  describe '.elf?' do
    subject { Android::Utils.elf?(data) }
    context 'assigns data start with elf magic' do
      let(:data) { "\x7fELF\xff\xff\xff" }
      it { should be_true }
    end
    context 'assigns nil' do
      let(:data) { nil }
      it { should be_false }
    end
    context 'assigns not elf data' do
      let(:data) { "\xff\xff\xff\xff\xff\xff" }
      it { should be_false }
    end
  end

  describe '.cert?' do
    subject { Android::Utils.cert?(data) }
    context 'assigns data start with x509 magic' do
      let(:data) { "\x30\x82\xff\xff\xff" }
      it { should be_true }
    end
    context 'assigns nil' do
      let(:data) { nil }
      it { should be_false }
    end
    context 'assigns not valid data' do
      let(:data) { "\xff\xff\xff\xff\xff\xff" }
      it { should be_false }
    end
  end

  describe '.dex?' do
    subject { Android::Utils.dex?(data) }
    context 'assigns dex file data' do
      let(:data) { File.read(sample_dex_path) }
      it { should be_true }
    end
    context 'assigns nil' do
      let(:data) { nil }
      it { should be_false }
    end
    context 'assings not dex data' do
      let(:data) { 'hogehoge' }
      it { should be_false }
    end
  end
  describe '.valid_dex?' do
    subject { Android::Utils.valid_dex?(data) }
    context 'assigns dex file data' do
      let(:data) { File.read(sample_dex_path) }
      it { should be_true }
    end
    context 'assigns nil' do
      let(:data) { nil }
      it { should be_false }
    end
    context 'assings not dex data' do
      let(:data) { 'hogehoge' }
      it { should be_false }
    end
  end
end

