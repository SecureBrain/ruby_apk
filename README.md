# ruby_apk
Android Apk static analysis library for Ruby.

[![Gem Version](https://badge.fury.io/rb/ruby_apk.png)](http://badge.fury.io/rb/ruby_apk)
[![Build Status](https://travis-ci.org/SecureBrain/ruby_apk.png)](https://travis-ci.org/SecureBrain/ruby_apk)

## Requirements
- ruby(>=1.9.x)

## Install
    $ gem install ruby_apk

## Usage
### Initialize
```ruby
  require 'ruby_apk'
  apk = Android::Apk.new('sample.apk') # set apk file path
```

### Apk
#### Listing files in Apk
```ruby
# listing files in apk
apk = Android::Apk.new('sample.apk')
apk.each_file do |name, data|
  puts "#{name}: #{data.size}bytes" # puts file name and data size
end
```

#### Find files in Apk
```ruby
  apk = Android::Apk.new('sample.apk')
  elf_files = apk.find{|name, data| data[0..3] == [0x7f, 0x45, 0x4c, 0x46] } # ELF magic number
```

#### Extract icon data in Apk (since 0.6.0)
```ruby
  apk = Android::Apk.new('sample.apk')
  icons = apk.icon # { "res/drawable-hdpi/ic_launcher.png" => "\x89PNG\x0D\x0A...", ... }
  icons.each do |name, data|
    File.open(File.basename(name), 'wb') {|f| f.write data } # save to file.
  end
```

#### Extract signature and certificate information from Apk (since v0.7.0)
```ruby
  apk = Android::Apk.new('sample.apk')
  signs = apk.signs # retrun Hash(key: signature file path, value: OpenSSL::PKCS7)
  signs.each do |path, sign|
    puts path # => "MATA-INF/CERT.RSA" or ...
    puts sign # => "-----BEGIN PKCS7-----\n..." PKCS7 object
  end

  certs = apk.certificates # retrun Hash(key: signature file path, value: OpenSSL::X509::Certificate)
  certs.each do |path, cert|
    puts path # => "MATA-INF/CERT.RSA" or ...
    puts cert # => "-----BEGIN CERTIFICATE-----\n..." # X509::Certificate object
  end
```
Note: Most apks have only one signature and cerficate.

### Manifest
#### Get readable xml
```ruby
  apk = Android::Apk.new('sample.apk')
  manifest = apk.manifest
  puts manifest.to_xml
```

#### Listing components and permissions
```ruby
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
```

#### Extract application label string
```ruby
  apk = Android::Apk.new('sample.apk')
  puts apk.manifest.label
```

### Resource
#### Extract resource strings from apk
```ruby
  apk = Android::Apk.new('sample.apk')
  rsc = apk.resource
  rsc.strings.each do |str|
    puts str
  end
```

#### Parse resource file directly
```ruby
  rsc_data = File.open('resources.arsc', 'rb').read{|f| f.read }
  rsc = Android::Resource.new(rsc_data)
```

### Resolve resource id
This feature supports only srting resources for now.

```ruby
  apk = Android::Apk.new('sample.apk')
  rsc = apk.resource
  
  # assigns readable resource id
  puts rsc.find('@string/app_name') # => 'application name'

  # assigns hex resource id
  puts rsc.find('@0x7f040000') # => 'application name'

  # you can set lang attribute.
  puts rsc.find('@0x7f040000', :lang => 'ja')
```


### Dex
#### Extract dex information
```ruby
  apk = Android::Apk.new('sample.apk')
  dex = apk.dex
  # listing string table in dex
  dex.strings.each do |str|
    puts str
  end

  # listing all class names
  dex.classes.each do |cls| # cls is Android::Dex::ClassInfo
    puts "class: #{cls.name}"
    cls.virtual_methods.each do |m| # Android::Dex::MethodInfo
      puts "\t#{m.definition}" # puts method definition
    end
  end
```

#### Parse dex file directly
```ruby
  dex_data = File.open('classes.dex','rb').read{|f| f.read }
  dex = Android::Dex.new(dex_data)
```


## Copyright

Copyright (c) 2012 SecureBrain. See LICENSE.txt for further details.

