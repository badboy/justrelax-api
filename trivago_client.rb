#!/usr/bin/env ruby
# encoding: utf-8

require 'bundler/setup'
require 'faraday'
require 'faraday_middleware'

class TrivagoClient
  def initialize
  @client = Faraday.new(:url => "http://api.trivago.com") do |faraday|
      faraday.request :url_encoded
      faraday.adapter Faraday.default_adapter
      faraday.response :json, :content_type => /\bjson$/

      faraday.headers["Username"] = "42"
      faraday.headers["Password"] = "RmfWhbWEMytruXiHfgGUUTNacNZmTFfp"
      faraday.headers["Accept"] = "application/vnd.trivago.api.v1+json"
      faraday.headers["TID"] = "Au6s16SJS4Vo394W5Sl2oOL1ac"
      faraday.headers["LocaleCode"] = "de"
      faraday.headers["LanguageCode"] = "De"
      faraday.headers["AppReleaseString"] = "ios_2_04"
      faraday.headers["Session"] = "C058C003-FFC0-4CFA-9B74-F9B47D705CB3"
      faraday.headers["User-Agent"] = "trivago/2.0.4 (iPhone; iOS 8.3; Scale/2.00)"
    end
  end

  def search(id, params)
    params["roomType"] ||= "DOUBLE"
    params["limit"] ||= 30
    params["offset"] ||= 0
    params["overallLiking"] ||= "1,2,3,4,5"
    params["currency"] ||= "EUR"
    params["categoryRange"] ||= "1,2,3,4,5"

    resp = @client.get("/hotelsearch/rest/regionSearch/#{id}", params)
    resp.body
  end

  def suggest(location)
    resp = @client.get("/hotelsearch/rest/suggest?q=#{location}")
    resp.body
  end

  def location_id(location)
    result = suggest(location)
    results = result["result"]

    if results.size > 0
      results.first["p"]
    else
      nil
    end
  end

  def location_search(location, params)
    id = location_id(location)
    return nil if id.nil?

    search(id, params)
  end
end
