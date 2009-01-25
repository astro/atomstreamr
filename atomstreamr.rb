require 'eventmachine'
require 'evma_xmlpushparser'
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
    @uri, callback = args
    @http_resp = ''
    @parser = Parser.new(callback)
  end

  def post_init
    @parser.post_init
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

    @parser.receive_data(data)
  end

  def unbind
    @parser.unbind
    EM::stop
  end

  ##
  # You'll need a modified LibXML-Ruby SAX parser
  #
  # gem sources -a http://gems.github.com
  # gem install julien51-eventmachine_xmlpushparser
  class Parser
    def initialize(callback)
      @callback = callback
      @elem = nil
    end

    include EventMachine::XmlPushParser

    def end_document
      EM::stop
    end
    def start_element(name, attributes = {})
      if @elem.nil? && name == 'atomStream'
      else
        e = REXML::Element.new(name)
        attributes.each do |n,v|
          if n == 'xmlns'
            e.add_namespace v
          else
            e.attributes[n] = v
          end
        end
        @elem = @elem ? @elem.add(e) : e
      end
    end
    def end_element(element)
      if @elem
        @callback.call(@elem) unless @elem.parent
        @elem = @elem.parent
      end
    end
    def characters(text)
      @elem.add(REXML::Text.new(text)) if @elem
    end
  end
end
