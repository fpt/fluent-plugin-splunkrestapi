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

  config_param :post_retry_max, :integer, :default => 3
  config_param :post_retry_interval, :integer, :default => 3 


  def configure(conf)
    super
    @output_proc = OUTPUT_PROCS[@output_type]
    @username, @password = @auth.split(':')
  end

  def start
    super
    @http = Net::HTTP::Persistent.new 'fluentd-plugin-splunkrestapi'
    @http.verify_mode = OpenSSL::SSL::VERIFY_NONE # TODO
    @http.headers['Content-Type'] = 'text/plain'
    $log.debug "initialized for splunkrestapi"
  end

  def shutdown
    # NOTE: call super before @http.shutdown because super may flush final output
    super

    @http.shutdown
    $log.debug "shutdown from splunkrestapi"
  end

  def emit(tag, es, chain)
    es.each {|time,record|
      emit_one(tag, time, record)
      $log.write "#{Time.at(time).localtime} #{tag}: #{@output_proc.call(record)}\n"
    }
    $log.flush

    chain.next
  end

  def emit_one(tag, time, record)
    uri = URI get_baseurl + "&source=#{tag}"
    post = Net::HTTP::Post.new uri.request_uri
    post.basic_auth @username, @password
    post.body = @output_proc.call(record)
    $log.debug "POST #{uri}"
    # retry up to :post_retry_max times
    1.upto(@post_retry_max) do |c|
      response = @http.request uri, post
      $log.debug "=> #{response.code} (#{response.message})"
      if response.code == "200"
        # success
        break
      elsif response.code.match(/^40/)
        # user error
        $log.error "#{uri}: #{response.code} (#{response.message})\n#{response.body}"
        break
      elsif c < @post_retry_max
        # retry
        sleep @post_retry_interval
        next
      else
        # other errors. fluentd will retry processing on exception
        # FIXME: this may duplicate logs when using multiple buffers
        raise "#{uri}: #{response.message}"
      end
    end
  end

  def get_baseurl
    base_url = "https://#{@server}/services/receivers/simple?sourcetype=#{@sourcetype}"
    base_url += "&host=#{@host}" if @host
    base_url += "&check-index=false" # TODO
    base_url
  end

end

end
