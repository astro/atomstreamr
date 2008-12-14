require 'uri'
require 'socket'
require 'rexml/document'
require 'rexml/parsers/sax2parser'
require 'rexml/source'

class ATOMStreamer
  def initialize(&block)
    @callback = block
    @elem = nil
  end

  def run(url)
    uri = URI::parse(url)
    sock = TCPSocket.new(uri.host, uri.port)
    sock.puts("GET #{uri.request_uri} HTTP/1.0\r\n" +
              "Host: #{uri.host}\r\n" +
              "\r\n")

    source = REXML::IOSource.new(sock)
    class << source
      def position; 0 end
    end
    parser = REXML::Parsers::SAX2Parser.new(source)
    parser.listen(:start_element) do |uri, localname, qname, attributes|
      if @elem.nil? and qname == 'atomStream'
      else
        e = REXML::Element.new(qname)
        e.add_attributes attributes
        @elem = @elem ? @elem.add(e) : e
      end
    end
    parser.listen(:end_element) do  |uri, localname, qname|
      if @elem
        @callback.call(@elem) unless @elem.parent
        @elem = @elem.parent
      end
    end
    parser.listen(:characters) do |text|
      @elem.add(REXML::Text.new(text)) if @elem
    end
    parser.listen(:cdata) do |text|
      @elem.add(REXML::Text.new(text)) if @elem
    end
    
    parser.parse
  end
end
