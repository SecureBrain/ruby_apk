# ruby_apk
Android Apk static analysis library for Ruby.

## Requirements
- ruby(>=1.9.x)
- rubyzip gem(>=0.9.9)

## Install
	$ gem install ruby_apk

## Usage
### Initialize
	require 'ruby_apk'
	apk = Android::Apk.new('sample.apk') # set apk file path

### Apk
#### Listing files in Apk
	# listing files in apk
	apk = Android::Apk.new('sample.apk')
	apk.each_file do |name, data|
		puts "#{name}: #{data.size}bytes" # puts file name and data size
	end

#### Find files in Apk
	apk = Android::Apk.new('sample.apk')
	elf_files = apk.find{|name, data| data[0..3] == [0x7f, 0x45, 0x4c, 0x46] } # ELF magic number

### Manifest
#### Get readable xml
	apk = Android::Apk.new('sample.apk')
	manifest = apk.manifest
	puts manifest.to_xml

#### Listing components and permissions
	apk = Android::Apk.new('sample.apk')
	manifest = apk.manifest
	# listing components
	manifest.components.each do |c| # 'c' is Android::Manifest::Component object
		puts "#{c.type}: #{c.name}" 
		c.intent_filters.each do |filter|
			puts "\t#{filter.type}"
		end
	end

	# listing use-permission tag
	manifest.use_permissions.each do |permission|
		puts permission
	end

### Resource
#### Extract resource strings from apk
	apk = Android::Apk.new('sample.apk')
	rsc = apk.resource
	rsc.strings.each do |str|
		puts str
	end

#### Parse resource file directly
	rsc_data = File.open('resources.arsc', 'rb').read{|f| f.read }
	rsc = Android::Resource.new(rsc_data)

### Dex
#### Extract dex information
	apk = Android::Apk.new('sample.apk')
	dex = apk.dex
	# listing string table in dex
	dex.strings do |str|
		puts str
	end

	# listing all class names
	dex.classes do |cls| # cls is Android::Dex::ClassInfo
		puts "class: #{cls.name}"
		cls.virtual_methods.each do |m| # Android::Dex::MethodInfo
			puts "\t#{m.definition}" # puts method definition
		end
	end

#### Parse dex file directly
	dex_data = File.open('classes.dex','rb').read{|f| f.read }
	dex = Android::Dex.new(dex_data)


## Copyright

Copyright (c) 2012 SecureBrain. See LICENSE.txt for further details.

