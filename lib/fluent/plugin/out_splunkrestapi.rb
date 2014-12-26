=begin

  Copyright (C) 2013 Keisuke Nishida

  Licensed to the Apache Software Foundation (ASF) under one
  or more contributor license agreements.  See the NOTICE file
  distributed with this work for additional information
  regarding copyright ownership.  The ASF licenses this file
  to you under the Apache License, Version 2.0 (the
  "License"); you may not use this file except in compliance
  with the License.  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing,
  software distributed under the License is distributed on an
  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
  KIND, either express or implied.  See the License for the
  specific language governing permissions and limitations
  under the License.

=end

require 'httparty'

module Fluent

class SplunkRESTAPIOutput < Output
  Plugin.register_output('splunkrestapi', self)

  OUTPUT_PROCS = {
    :json => Proc.new {|record| Yajl.dump(record) },
    :hash => Proc.new {|record| record.to_s },
  }

  def initialize
    require 'net/http/persistent'
    super
  end

  config_param :output_type, :default => :json do |val|
    case val.downcase
    when 'json'
      :json
    when 'hash'
      :hash
    else
      raise ConfigError, "stdout output output_type should be 'json' or 'hash'"
    end
  end 

  # for Splunk REST API
  config_param :server, :string, :default => 'localhost:8089'
  config_param :auth, :string, :default => nil # TODO: required with rest

  # Event parameters
  config_param :host, :string, :default => nil # TODO: auto-detect
  config_param :sourcetype, :string, :default => 'fluent'


  def configure(conf)
    super
    HTTParty::Basement.default_options.update(verify: false)
    @output_proc = OUTPUT_PROCS[@output_type]
    @username, @password = @auth.split(':')
  end

  def start
    super
    $log.debug "initialized for splunkrestapi"
  end

  def shutdown
    super
    $log.debug "shutdown from splunkrestapi"
  end

  def emit(tag, es, chain)
    es.each {|time,record|
      emit_one(tag, time, record)
      # $log.write "#{Time.at(time).localtime} #{tag}: #{@output_proc.call(record)}\n"
    }
    # $log.flush

    chain.next
  end

  def emit_one(tag, time, record)
    uri = make_uri()
    body = @output_proc.call(record)
    options = { :headers => { 'Content-Type' => 'text/plain' } }
    basic_auth = {:username => @username, :password => @password}
    post_data = { :body => body, :options => options, :basic_auth => basic_auth }

    $log.debug "POST #{uri}"
    begin
      resp = HTTParty.post(uri.request_uri, post_data)
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      log.error "HTTParty post timeout #{e.inspect}"
      return nil
    end

    $log.debug "=> #{resp.code}"
    if response.code != "200"
      if response.code.match(/^40/)
        $log.error "#{uri}: #{resp.code}\n#{resp.body}"
      else
        raise "#{uri}: #{resp.code}\n#{resp.body}"
      end
    end
  end

  def make_uri(tag)
    uri  = "https://#{@server}/services/receivers/simple"
    uri += "?sourcetype=#{@sourcetype}"
    uri += "&host=#{@host}" if @host
    uri += "&check-index=false" # TODO
    uri += "&source=#{tag}"
    URI(uri)
  end

 end

end
