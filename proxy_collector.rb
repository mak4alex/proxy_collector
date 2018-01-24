require 'open-uri'
require 'set'
require 'nokogiri'
require 'base64'
require 'pry'

class ProxyCollector

  HTTP_TYPE  = 'http'
  SOCKS_TYPE = ''

  def initialize(args)
    @proxy_scrapers = [
 #     USProxyOrgScraper.new('https://www.us-proxy.org/'),
  #    USProxyOrgScraper.new('https://free-proxy-list.net/'),
      FreeProxyCzScraper.new('http://free-proxy.cz/en/')   
    ]
    @proxies        = []
    @output_file    = args[:output_file]
  end

  def run
    @proxy_scrapers.each do |proxy_scraper|
      puts "Start proxy #{proxy_scraper.class.name}"
      while proxy_scraper.has_more?
        @proxies += proxy_scraper.fetch_proxy
      end
    end

    @proxies.compact!
    @proxies.map! do |p| 
      "#{p[:ip]}:#{p[:port]}#{format_type(p[:type])}" 
    end
    
    File.open(@output_file, 'w') do |file| 
      file.write(@proxies.sort.uniq.join("\n"))
    end
    puts "#{@proxies.size} proxies were saved to #{@output_file}"
  end

  def format_type(type)
    type =~ /#{HTTP_TYPE}/i ? "@#{HTTP_TYPE}" : SOCKS_TYPE    
  end
end


class BaseProxyScraper
  def initialize(seed)
    @todo_queue = Queue.new
    @todo_queue.push(seed)
    @downloaded_count = 0
  end

  def has_more?
    !@todo_queue.empty?
  end

  def fetch_proxy
    has_more? ? scrape_proxy : []
  end

private

  def download
    uri = URI.parse(@todo_queue.pop)
    puts "Start download #{uri.to_s}"
    page_body = uri.read
    @downloaded_count = @downloaded_count.next
    page_body
  end    
end


class USProxyOrgScraper < BaseProxyScraper

private
  
  def scrape_proxy
    page_body = download
    document = Nokogiri::HTML(page_body)
    document.xpath('//table[@id="proxylisttable"]/tbody/tr').map do |proxy_node|
      next if proxy_node.text !~ /\d+\.\d+\.\d+\.\d+/

      type = proxy_node.xpath('./td')[6].text == 'yes' ? 'https' : 'http'
      {
        ip:   proxy_node.xpath('./td')[0].text,
        port: proxy_node.xpath('./td')[1].text,
        type: type
      }
    end
  end   

end


class FreeProxyCzScraper < BaseProxyScraper

  def initialize(seed)
    super(seed)
    (2..150).each do |index|
      @todo_queue.push("http://free-proxy.cz/en/proxylist/main/#{index}")
    end
  end

private
  
  def scrape_proxy
    page_body = download
    document = Nokogiri::HTML(page_body)
    document.xpath('//table[@id="proxy_list"]/tbody/tr').map do |proxy_node|
      next unless proxy_node.at('.//span[@class="fport"]')

      ip_base64 = proxy_node.at('.//script').text[/"(.*)"/, 1]
      {
        ip:   Base64.decode64(ip_base64),
        port: proxy_node.at('.//span[@class="fport"]').text,
        type: proxy_node.at('./td[3]').text
      }
    end

  end 

end

args = {
  output_file: './public_proxy_bd.txt'
}

ProxyCollector.new(args).run
