# encoding: utf-8
require 'rexml/document'

module Android
  class Layout
    # @return [Hash] { path => Layout }
    def self.collect_layouts(apk)
      targets = apk.find {|name, data| name =~ /^res\/layout\/*/ }
      ret = {}
      targets.each do |path| 
        data = apk.file(path)
        data.force_encoding(Encoding::ASCII_8BIT)
        ret[path] = nil
        begin
          ret[path] = Layout.new(data, path) if AXMLParser.axml?(data)
        rescue => e
          $stderr.puts e
        end
      end
      ret
    end

    # @return [String] layout file path
    attr_reader :path
    # @return [REXML::Document] xml document object
    attr_reader :doc

    def initialize(data, path=nil)
      @data = data
      @path = path
      @doc = AXMLParser.new(data).parse
    end

    # @return [String] xml string
    def to_xml(indent=4)
      xml = ''
      formatter = REXML::Formatters::Pretty.new(indent)
      formatter.write(@doc.root, xml)
      xml
    end
  end
end

