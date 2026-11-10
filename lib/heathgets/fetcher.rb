require "net/http"
require "uri"
require "date"
require "cgi"

module Heathgets
  # Reads Heathcliff strip pages from Creators Syndicate (the strip's syndicate).
  #
  # Each page carries:
  #   og:title  "Heathcliff for Nov 09, 2026, by Peter Gallagher"  -> strip date
  #   og:image  direct URL of the strip image
  #   #nav_prev link to the previous day's page (URLs use opaque ids, so
  #             older strips are reached by walking these links)
  class Fetcher
    LATEST_URL = "https://www.creators.com/read/heathcliff".freeze
    USER_AGENT = "heathgets/#{VERSION} (personal daily archive)".freeze
    MAX_REDIRECTS = 5

    Page = Struct.new(:url, :date, :image_url, :prev_url, keyword_init: true)
    Image = Struct.new(:bytes, :content_type, :extension, keyword_init: true)

    EXTENSIONS = {
      "image/jpeg" => "jpg",
      "image/png" => "png",
      "image/gif" => "gif",
      "image/webp" => "webp"
    }.freeze

    def latest
      page(LATEST_URL)
    end

    def page(url)
      body, = get(url)
      self.class.parse(body, url)
    end

    def image(url)
      bytes, content_type = get(url)
      type = content_type.to_s.split(";").first.to_s.strip.downcase
      ext = EXTENSIONS[type] or raise Error, "unexpected content type #{content_type.inspect} for #{url}"
      Image.new(bytes: bytes, content_type: type, extension: ext)
    end

    # Pure parsing, kept separate so it can be tested against saved pages.
    def self.parse(html, url)
      title = meta(html, "og:title") or raise Error, "no og:title on #{url} (page layout changed?)"
      image = meta(html, "og:image") or raise Error, "no og:image on #{url} (page layout changed?)"

      m = title.match(/for ([A-Z][a-z]{2}) (\d{1,2}), (\d{4})/) or
        raise Error, "can't find a date in og:title #{title.inspect} on #{url}"
      date = Date.strptime("#{m[1]} #{m[2]} #{m[3]}", "%b %d %Y")

      prev = html[/<a[^>]*id="nav_prev"[^>]*href="([^"]+)"/, 1] ||
             html[/<a[^>]*href="([^"]+)"[^>]*id="nav_prev"/, 1]

      Page.new(
        url: url,
        date: date,
        image_url: URI.join(url, CGI.unescapeHTML(image)).to_s,
        prev_url: prev && URI.join(url, CGI.unescapeHTML(prev)).to_s
      )
    end

    def self.meta(html, property)
      tag = html.scan(/<meta\b[^>]*>/i).find { |t| t.include?(%(property="#{property}")) }
      tag && CGI.unescapeHTML(tag[/content="([^"]*)"/, 1].to_s).then { |v| v.empty? ? nil : v }
    end

    private

    def get(url, redirects = 0)
      uri = URI(url)
      req = Net::HTTP::Get.new(uri)
      req["User-Agent"] = USER_AGENT
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                                open_timeout: 15, read_timeout: 30) { |http| http.request(req) }

      case res
      when Net::HTTPSuccess
        [res.body, res["Content-Type"]]
      when Net::HTTPRedirection
        raise Error, "too many redirects fetching #{url}" if redirects >= MAX_REDIRECTS
        get(URI.join(url, res["Location"]).to_s, redirects + 1)
      else
        raise Error, "HTTP #{res.code} fetching #{url}"
      end
    end
  end
end
