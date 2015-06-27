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

  if more[:price_max]
    params["maxPrice"]   = more[:price_max]
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

Cuba.plugin Cuba::Mote
Cuba.plugin Cuba::TextHelpers

# Use Cookies, the secret should be random
# Generate a new one with:
#     openssl rand -base64 32
Cuba.use Rack::Session::Cookie, :secret => "EsnoAqxjvP0RGWHo8TpLFVXtzhrsa2"

Cuba.define do
  on get do
    on "holiday", param("from"), param("to"), param("location") do |from,to,location|

      roomtype = req.params["room"] || "double"

      price_max   = req.params["price_max"]

      more = {
        roomtype:    roomtype,
        price_max:   price_max
      }

      res.headers["Content-Type"] = "application/json; charset=utf-8"
      if data = cached(from,to,location, more)
        res.write data
      else
        t = TrivagoClient.new

        params = new_params(from, to, more)
        items = t.location_search(location, params)
        p items

        if items.empty? || items['hotels'].empty?
          res.write [].to_json
        else
          hotels = items['hotels']
          j = hotels.map { |hotel|
            offer = hotel['offers'][0]
            {
              name:   hotel['name'],
              price:  offer['price']['value'],
              link:   offer['link'],
            }
          }

          cache_now(from,to,location,j.to_json, more)
          res.write j.to_json
        end
      end
    end
  end
end
