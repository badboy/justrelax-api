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

require_relative "trivago_client"

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

def new_params(from, to, more)
  params = {
    fromDate: from,
    toDate: to,
  }

  params["roomType"] = more[:roomtype].upcase

  params["categoryRange"] = more[:category] if more[:category]
  params["overallLiking"] = more[:like]     if more[:like]

  if more[:max_price]
    params["maxPrice"]   = more[:max_price]
  end

  params
end

def redis
  $redis ||= Redic.new
end

def cache_key(from,to,location,more={})
  key = "%s/%s/%s" % [from,to,location]

  more.each do |k,v|
    key << "/%s=%s" % [k,v] if k && v
  end

  key
end

def cached(from,to,location,more={})
  key = cache_key(from,to,location,more)
  redis.call("GET", key)
end

def cache_now(from, to, location, data, more)
  key = cache_key(from, to, location, more)
  redis.call("SET", key, data, "EX", 60*60)
end

def map_category(cat)
  return "1,2,3,4,5" if cat.nil?

  case cat
  when "shit"
    return ""
  when "best"
    return "5"
  else
    return "1,2,3,4,5"
  end
end

def map_liking(like)
  return "1,2,3,4,5" if like.nil?

  case cat
  when "shit"
    return "1"
  when "best"
    return "5"
  else
    return "1,2,3,4,5"
  end
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

      roomtype  = req.params["room"] || "double"
      max_price = req.params["max_price"] || 5000
      category  = map_category(req.params["category"])
      like      = map_category(req.params["like"])

      more = {
        roomtype:    roomtype,
        max_price:   max_price,
        category:    category,
        like:        like,
      }

      res.headers["Content-Type"] = "application/json; charset=utf-8"
      if data = cached(from, to, location, more)
        res.write data
      else
        t = TrivagoClient.new

        params = new_params(from, to, more)
        items = t.location_search(location, params)

        if items.empty? || items['hotels'].empty?
          res.write [].to_json
        else
          hotels = items['hotels']
          j = hotels.map { |hotel|
            offer = hotel['offers'][0]
            price = offer['price'] if offer
            price = price['value'] if price

            link = offer['link'] if offer

            {
              name:   hotel['name'],
              price:  price || 0,
              city:   hotel['city'],
              image:  hotel['imageUrl'],
              link:   link || "",
            }
          }

          data = {results: j}
          cache_now(from,to,location,data.to_json, more)
          res.write data.to_json
        end
      end
    end
  end
end
