require 'httparty'
require 'nokogiri'
require 'pp'

class HtmlParserIncluded < HTTParty::Parser
  SupportedFormats.merge!(
    'text/html' => :html,
    'application/rss+xml' => :rss
  )

  def html
    Nokogiri::HTML(body)
  end
  
  def rss
    Nokogiri::XML(body)
  end
end

class Page
  include HTTParty
  parser HtmlParserIncluded
end

class RssPage
  def self.parse(url)
    rss = Page.get(url)
    pp rss
    items = rss.css('//item').map do |item|
      id, house = item.css('title/text()')[0].to_s.split(/\s*:\s*/, 2)
      {
        :id => id,
        :house => house,
        :description => item.css('description/text()')[0].to_s,
        :pub_date => item.css('pubDate/text()')[0].to_s,
        :link => item.css('link/text()')[0].to_s,
      }
    end
  end
end

namespace :wq do
  namespace :nl do
    desc "parses nl written questions"
    task :parse => [:environment] do
      pp RssPage.parse('https://zoek.officielebekendmakingen.nl/kamervragen_zonder_antwoord/rss')
    end
  end
end