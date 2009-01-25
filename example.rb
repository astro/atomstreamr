#!/usr/bin/env ruby

require 'atomstreamr'
require 'xmpp4r/rexmladdons'

def on_element(e)
  if e.name == 'feed'
    puts e.first_element_text('title').to_s
    e.each_element('entry') { |entry|
      puts "  - " + entry.first_element_text('title').to_s
      puts "    " + entry.first_element_text('link').to_s
    }
  end
end

EM::run do
  ATOMStreamer.run 'http://updates.sixapart.com/atom-stream.xml', &method(:on_element)
end


