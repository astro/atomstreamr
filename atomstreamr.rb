require 'eventmachine'
require 'uri'
require 'rexml/document'
require 'libxml'

class ATOMStreamer < EventMachine::Connection
  def self.run(url, &block)
    uri = URI::parse(url)

    # If initialize is wrong EM bails with
    # EventMachine::ConnectionNotBound
    EM::connect(uri.host, uri.port, self, [uri, block])
  end

  def initialize(args)
    super
    @uri, @callback = args
    @http_resp = ''
    @parser = LibXML::XML::SaxParser.new
    @parser.callbacks = self
    @elem = nil
  end

  def connection_completed
    send_data("GET #{@uri.request_uri} HTTP/1.0\r\n" +
              "Host: #{@uri.host}\r\n" +
              "\r\n")
  end

  def receive_data(data)
    if @http_resp
      @http_resp += data
      h, t = @http_resp.split("\r\n\r\n", 2)
      if t
        @http_resp = nil
      end
      data = t.to_s
    end

    @parser.parse(data)
  end

  def unbind
    EM::stop
  end

  ##
  # You'll need a modified LibXML-Ruby SAX parser
  #
  # gem sources -a http://gems.github.com
  # gem install astro-libxml-ruby
  include LibXML::XML::SaxParser::Callbacks

  def on_start_element(name, attributes = {})
    if @elem.nil? && name == 'atomStream'
    else
      e = REXML::Element.new(name)
      attributes.each do |n,v|
        if n
          e.attributes[n] = v
        else
          e.add_namespace v
        end
      end
      @elem = @elem ? @elem.add(e) : e
    end
  end
  def on_end_element(element)
    if @elem
      @callback.call(@elem) unless @elem.parent
      @elem = @elem.parent
    end
  end
  def on_characters(text)
    @elem.add(REXML::Text.new(text)) if @elem
  end
end
