#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'oga'
require 'json'
require 'open-uri'
require 'uri'
require 'rack'
require 'base64'
require 'redic'

require "cuba"
require "cuba/contrib"
require "mote"

SUGGEST_BASE = "http://www.trivago.de/search/de-DE-DE/v9_06_2_ae_cache/suggest?q="
URL_BASE = "http://www.trivago.de/search/region?"


Result = Struct.new(
  :id,
  :title,
  :prices,
  :stars,
  :type,
  :link
) do
  def to_json(*args)
    {
      title:   self.title,
      prices:  self.prices,
      stars:   self.stars,
      type:    self.type,
      link:    self.link,
    }.to_json(*args)
  end
end

def strip_full(text)
  text.to_s
    .gsub(/\p{Blank}/u, ' ')
    .gsub(/\xe2\x80\x8e/u, '')
    .strip
end

def to_price(price)
  price.sub(/€/,'').to_i
end

def text_or_empty(html, css)
  t = html.css(css).first
  return "" unless t
  strip_full(t.text)
end

def parse_result text
  h = Oga.parse_html(text)

  title     = text_or_empty(h, "h3").gsub(/,$/,'')

  price_max = text_or_empty(h, ".price_max")
  price_min = text_or_empty(h, ".price_min")

  price_max = to_price(price_max)
  price_min = to_price(price_min)

  stars = text_or_empty(h, ".stars").to_i
  type  = text_or_empty(h, ".pointer").split(/\n/).first

  link = Base64::decode64(
    h.css("button").first.parent.attr("data-link").value
  )

  Result.new(
    nil,
    title,
    [price_min, price_max],
    stars,
    type,
    link
  )
end

def params_to_url(params)
  params.map {|k,v|
    "%s=%s" % [CGI.escape(k.to_s), CGI.escape(v.to_s)]
  }.join("&")
end

def get_location_id(location)
  url = SUGGEST_BASE + CGI.escape(location)
  doc = JSON.parse(open(url).read)
  doc["result"].first["p"]
end


#url = "http://www.trivago.de/search/region?iPathId=36103&iGeoDistanceItem=0&aDateRange%5Barr%5D=2015-07-19&aDateRange%5Bdep%5D=2015-07-20&iRoomType=7&bIsTotalPrice=false&iViewType=0&bIsSeoPage=false&bIsSitemap=false&&_=1435406031769"

def new_params(from, to, location)
  location_id = get_location_id(location)
  {
    "aDateRange[arr]" => from,
    "aDateRange[dep]" => to,
    "iRoomType"       => "7",
    "iPathId"         => location_id
  }
end

def redis
  $redis ||= Redic.new
end

def cached(from,to,location)
  key = "%s/%s/%s" % [from,to,location]
  redis.call("GET", key)
end

def cache_now(from,to,location,data)
  key = "%s/%s/%s" % [from,to,location]
  redis.call("SET", key, data, "EX", 60*60)
end

Cuba.plugin Cuba::Mote
Cuba.plugin Cuba::TextHelpers

# Use Cookies, the secret should be random
# Generate a new one with:
#     openssl rand -base64 32
Cuba.use Rack::Session::Cookie, :secret => "EsnoAqxjvP0RGWHo8TpLFVXtzhrsa2"

Cuba.define do
  on get do
    on "holiday", param("from"), param("to"), param("location") do |from,to,location|

      res.headers["Content-Type"] = "application/json; charset=utf-8"
      if data = cached(from,to,location)
        res.write data
      else
        params = new_params(from,to,location)
        url = URL_BASE + params_to_url(params)
        doc = JSON.parse(open(url).read)
        items = doc["items"]

        j = items.map { |item|
          t = parse_result(item['html'])
          t.id = item['id']
          t
        }

        cache_now(from,to,location,j.to_json)
        res.write j.to_json
      end
    end
  end
end
