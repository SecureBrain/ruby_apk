require 'zip' # need rubyzip gem -> doc: http://rubyzip.sourceforge.net/
require 'digest/md5'
require 'digest/sha1'
require 'digest/sha2'
require 'openssl'

module Android
  class NotApkFileError < StandardError; end
  class NotFoundError < StandardError; end

  # apk object class
  class Apk

    # @return [String] apk file path
    attr_reader :path
    # @return [Android::Manifest] manifest instance
    # @return [nil] when parsing manifest is failed.
    attr_reader  :manifest
    # @return [Android::Dex] dex instance
    # @return [nil] when parsing dex is failed.
    attr_reader :dex
    # @return [String] binary data of apk
    attr_reader :bindata
    # @return [Resource] resouce data
    # @return [nil] when parsing resource is failed.
    attr_reader :resource

    # AndroidManifest file name
    MANIFEST = 'AndroidManifest.xml'
    # dex file name
    DEX = 'classes.dex'
    # resource file name
    RESOURCE = 'resources.arsc'

    # create new apk object
    # @param [String] filepath apk file path
    # @raise [Android::NotFoundError] path file does'nt exist
    # @raise [Android::NotApkFileError] path file is not Apk file.
    def initialize(filepath)
      @path = filepath
      raise NotFoundError, "'#{filepath}'" unless File.exist? @path
      begin
        @zip = Zip::ZipFile.open(@path)
      rescue Zip::ZipError => e
        raise NotApkFileError, e.message 
      end

      @bindata = File.open(@path, 'rb') {|f| f.read }
      @bindata.force_encoding(Encoding::ASCII_8BIT)
      raise NotApkFileError, "manifest file is not found." if @zip.find_entry(MANIFEST).nil?
      begin
        @resource = Android::Resource.new(self.file(RESOURCE))
      rescue => e
        $stderr.puts "failed to parse resource:#{e}"
        #$stderr.puts e.backtrace
      end
      begin
        @manifest = Android::Manifest.new(self.file(MANIFEST), @resource)
      rescue => e
        $stderr.puts "failed to parse manifest:#{e}"
        #$stderr.puts e.backtrace
      end
      begin
        @dex = Android::Dex.new(self.file(DEX))
      rescue => e
        $stderr.puts "failed to parse dex:#{e}"
        #$stderr.puts e.backtrace
      end
    end

    # return apk file size
    # @return [Integer] bytes
    def size
      @bindata.size
    end

    # return hex digest string of apk file
    # @param [Symbol] type hash digest type(:sha1, sha256, :md5)
    # @return [String] hex digest string
    # @raise [ArgumentError] type is knknown type
    def digest(type = :sha1)
      case type
      when :sha1
        Digest::SHA1.hexdigest(@bindata)
      when :sha256
        Digest::SHA256.hexdigest(@bindata)
      when :md5
        Digest::MD5.hexdigest(@bindata)
      else
        raise ArgumentError
      end
    end

    # returns date of AndroidManifest.xml as Apk date
    # @return [Time]
    def time
      entry(MANIFEST).time
    end

    # @yield [name, data]
    # @yieldparam [String] name file name in apk
    # @yieldparam [String] data file data in apk
    def each_file
      @zip.each do |entry|
        next unless entry.file?
        yield entry.name, @zip.read(entry)
      end
    end

    # find and return binary data with name
    # @param [String] name file name in apk(fullpath)
    # @return [String] binary data
    # @raise [NotFoundError] when 'name' doesn't exist in the apk
    def file(name) # get data by entry name(path)
      @zip.read(entry(name))
    end

    # @yield [entry]
    # @yieldparam [Zip::Entry] entry zip entry
    def each_entry
      @zip.each do |entry|
        next unless entry.file?
        yield entry
      end
    end

    # find and return zip entry with name
    # @param [String] name file name in apk(fullpath)
    # @return [Zip::ZipEntry] zip entry object
    # @raise [NotFoundError] when 'name' doesn't exist in the apk
    def entry(name)
      entry = @zip.find_entry(name)
      raise NotFoundError, "'#{name}'" if entry.nil?
      return entry
    end

    # find files which is matched with block condition
    # @yield [name, data] find condition
    # @yieldparam [String] name file name in apk
    # @yieldparam [String] data file data in apk
    # @yieldreturn [Array] Array of matched entry name
    # @return [Array] Array of matched entry name
    # @example
    #   apk = Apk.new(path)
    #   elf_files = apk.find  { |name, data|  data[0..3] == [0x7f, 0x45, 0x4c, 0x46] } # ELF magic number
    def find(&block)
      found = []
      self.each_file do |name, data|
        ret = block.call(name, data)
        found << name if ret
      end
      found
    end

    # extract icon data from AndroidManifest and resource.
    # @return [Hash{ String => String }] hash key is icon filename. value is image data
    # @raise [NotFoundError]
    # @since 0.6.0
    def icon
      icon_id = @manifest.doc.elements['/manifest/application'].attributes['icon']
      if /^@(\w+\/\w+)|(0x[0-9a-fA-F]{8})$/ =~ icon_id
        drawables = @resource.find(icon_id)
        Hash[drawables.map {|name| [name, file(name)] }]
      else 
        { icon_id => file(icon_id) } # ugh!: not tested!!
      end
    end

    # get application label from AndroidManifest and resources.
    # @param [String] lang language code like 'ja', 'cn', ...
    # @return [String] application label string
    # @return [nil] when label is not found
    # @deprecated move to {Android::Manifest#label}
    # @since 0.6.0
    def label(lang=nil)
      @manifest.label
    end

    # get screen layout xml datas
    # @return [Hash{ String => Android::Layout }] key: laytout file path, value: layout object
    # @since 0.6.0
    def layouts
      @layouts ||= Layout.collect_layouts(self) # lazy parse
    end

    # apk's signature information
    # @return [Hash{ String => OpenSSL::PKCS7 } ] key: sign file path, value: signature
    # @since 0.7.0
    def signs
      signs = {}
      self.each_file do |path, data|
        # find META-INF/xxx.{RSA|DSA}
        next unless path =~ /^META-INF\// && data.unpack("CC") == [0x30, 0x82]
        signs[path] = OpenSSL::PKCS7.new(data)
      end
      signs
    end

    # certificate info which is used for signing
    # @return [Hash{String => OpenSSL::X509::Certificate }] key: sign file path, value: first certficate in the sign file
    # @since 0.7.0
    def certificates
      return Hash[self.signs.map{|path, sign| [path, sign.certificates.first] }]
    end
  end
end

