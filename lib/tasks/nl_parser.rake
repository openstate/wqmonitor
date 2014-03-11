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

class WrittenQuestionPage
  def self.parse(url)
    kv = Page.get(url)
    remapper = {
      'DC.type' => 'type',
      'DCTERMS.issued' => 'published',
      'OVERHEID.organisationType' => 'organisation',
      'DCTERMS.available' => 'available',
      'DC.title' => 'title', #TODO: dutch differs between question and answer title
      'OVERHEID.category' => 'category',
      'DC.creator' => 'creator',
      'OVERHEIDop.datumIndiening' => 'submitted',
      'DC.identifier' => 'id',
      'OVERHEIDop.vergaderjaar' => 'season',
      'OVERHEIDop.indiener' => 'submitter',
      'OVERHEIDop.vraagnummer' => 'question_id',
      'OVERHEIDop.documentStatus' => 'status',
      'DCTERMS.language' => 'language',
      'OVERHEIDop.publicationName' => 'pubilication',
      'OVERHEIDop.datumOntvangst' => 'answered',
      'OVERHEIDop.ontvanger' => 'recepient',
      'OVERHEIDop.aanhangselNummer' => 'attachment_number',
      
    }
    meta_headers = kv.css('/html/head//meta').map do |meta|
      orig_meta_name = meta.css('@name')[0].to_s
      if remapper.has_key?(orig_meta_name) then
        meta_name = remapper[orig_meta_name]
      elsif orig_meta_name != ''
        meta_name = orig_meta_name
      end
      {
        meta_name => meta.css('@content')[0].to_s
      }
    end
    pdf_link = 'https://zoek.officielebekendmakingen.nl/' + kv.css('#downloadPdfHyperLink/@href')[0].value
    {
      :meta => meta_headers,
      :pdf_link => pdf_link
    }
  end
end

class WrittenQuestionPDF
  def self.convert(url)
    system('wget -q -O /tmp/kv.pdf ' + url)
    html = `pdftohtml -noframes -stdout /tmp/kv.pdf`
    system('rm /tmp/kv.pdf')
    html
  end
end

class RssPage
  def self.parse(url)
    rss = Page.get(url)
    items = rss.css('//item').map do |item|
      id, house = item.css('title/text()')[0].to_s.split(/\s*:\s*/, 2)
      link = item.css('link/text()')[0].to_s
      data = WrittenQuestionPage.parse(link)
      text = WrittenQuestionPDF.convert(data[:pdf_link])
      {
        :id => id,
        :house => house,
        :description => item.css('description/text()')[0].to_s,
        :pub_date => item.css('pubDate/text()')[0].to_s,
        :link => link,
        :data => data,
        :text => text
      }
    end
  end
end

namespace :wq do
  namespace :nl do
    desc "parses nl written questions"
    task :parse => [:environment] do
      pp RssPage.parse('https://zoek.officielebekendmakingen.nl/kamervragen_aanhangsel/rss')
      # pp RssPage.parse('https://zoek.officielebekendmakingen.nl/kamervragen_zonder_antwoord/rss')
    end
  end
end