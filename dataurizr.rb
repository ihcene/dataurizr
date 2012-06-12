require 'open-uri'
require 'uri'
require 'nokogiri'
require 'base64'

class Dataurizr
  def initialize(url)
    @url = prefix_url_if_necessary(url)
    
    @doc = Nokogiri::HTML(open(@url), nil, 'UTF-8')
    
    @imgs = []
  end
  
  def to_html
    @doc.to_html
  end
  
  alias to_s to_html
  
  def do_images
    @doc.css('img, input[type=image]').each do |img|
      img[:src] = read_encode_img(img[:src]);
    end
  end
  
  def do_css
    @doc.css('link[rel=stylesheet]').each do |link|
      absolute_url = get_absolute_url(link[:href])
      
      style_tag = @doc.create_element('style')
      
      # add this attribute to distinguich the original style tags from the embeded ones
      style_tag[:"data-embedded"] = "true"
      
      begin
        style_tag.content = cssfile_process(grab_content(absolute_url), absolute_url)
        
        link.after(style_tag)
        link.remove
      end
    end
    
    @doc.css('style:not([data-embedded])').each do |style|
      style.content = cssfile_process(style.content, @url)
    end
  end
  
  def do_javascript
    @doc.css('script').each do |script|
      unless script[:src] == nil
        absolute_url = get_absolute_url(script[:src])
        
        next if absolute_url.nil?
        
        begin
          script_content = grab_content(absolute_url)
          script.remove_attribute("src")
          script.content = "<![CDATA[\n#{script_content}\n]]>"
        end
      end
    end
  end
  
  def do_inline_css
    @doc.css('[style]').each do |element|
      element[:style] = cssfile_process(element[:style], @url)
    end
  end
  
  def available_actions
    self.methods.select{ |e| e.slice(0, 3) == "do_" }
  end
  
  private
    def cssfile_process(file_content, file_path)
      file_content.gsub(%r{url\(["']?(.+?)["']?\)}) { |s| "url(#{read_encode_img($1, file_path)})" }
    end
  
    def grab_content(url)
      # Simple caching
      @cache ||= {}
      
      if @cache.has_key? url
        puts "Cached : #{url}"
        @cache[url]
      else
        puts url
        begin
          @cache[url] = open(url).read
        rescue OpenURI::HTTPError
          (@notfound ||= []) << url
          puts "404 : #{url}"
          ""
        rescue OpenSSL::SSL::SSLError
          ""
        end
      end
    end
    
    def prefix_url_if_necessary(url)
      if url =~ %r{\Ahttps?\://}
        url
      else
        "http://" + url
      end
    end
    
    def read_encode_img(uri, to = @url)
      absolute_url = get_absolute_url(uri, to)
      
      # TODO : make true image type detection
      
      img = grab_content(absolute_url)
      
      if img != ""
        "data:image/#{detect_mime_type(uri)};base64,#{Base64.strict_encode64(img)}"
      end
    end
    
    def get_absolute_url(uri, to = @url)
      # already absolute (with scheme)
      if uri =~ %r{\Ahttp://}
        uri
      elsif uri =~ %r{\A/}
        p = URI(to)
        p.path = ''
        p.query = nil
        p.to_s + uri
      else
        p = URI(to)
        p.path = pop_file_part(p.path)
        p.query = nil
        p.to_s + uri
      end
    end
    
    def pop_file_part(path)
      return path if path[-1, 1] == "/"
      
      without_file = path.split('/')
      without_file.pop
      without_file.join('/') + "/"
    end
    
    def detect_mime_type(filename)
      filename.split('.').pop.downcase
    end
end