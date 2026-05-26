# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "protocol/http/headers"

require "async/http/protocol/request"

require_relative "connection"
require_relative "input"
require_relative "output"

module Async
	module HTTP
		module Protocol
			module HTTP3
				# An incoming HTTP/3 request.
				class Request < Protocol::Request
					# Initialize the pending request.
					# @parameter connection [Server] The HTTP/3 server connection.
					# @parameter stream_id [Integer] The native stream identifier.
					def initialize(connection, stream_id)
						super(nil, nil, nil, nil, VERSION_STRING, nil, nil, nil, self.public_method(:write_interim_response))
						
						@connection = connection
						@stream_id = stream_id
						@raw_headers = []
						@pending_chunks = []
						@length = nil
						@enqueued = false
					end
					
					attr :stream_id
					
					# @returns [Connection] The underlying HTTP/3 server connection.
					def connection
						@connection
					end
					
					# Receive a request header.
					def header_received(name, value)
						@raw_headers << [name, value]
					end
					
					# Finish the request headers and enqueue the request.
					def headers_finished(is_final)
						return unless is_final
						
						headers = @raw_headers
						@raw_headers = []
						@headers = ::Protocol::HTTP::Headers.new
						
						headers.each do |key, value|
							case key
							when SCHEME
								@scheme = value
							when AUTHORITY
								@authority = value
							when METHOD
								@method = value
							when PATH
								@path = value
							when CONTENT_LENGTH
								@length = Integer(value)
							else
								@headers.add(key, value) unless key.start_with?(":")
							end
						end
						
						if @length || @pending_chunks.any?
							@body = Input.new(@length)
							
							@pending_chunks.each do |chunk|
								@body.write(chunk)
							end
							
							@pending_chunks.clear
						end
						
						enqueue!
					end
					
					# Receive an HTTP/3 request body chunk.
					def data_received(chunk)
						if @body
							@body.write(chunk)
						else
							@pending_chunks << chunk
						end
					end
					
					# Finish the request stream.
					def stream_finished
						@body&.close_write
					end
					
					# Send a response for this request.
					# @parameter response [Protocol::HTTP::Response | Nil] The response to send.
					def send_response(response)
						unless response
							return @connection.submit_response(@stream_id, [[STATUS, "500"]])
						end
						
						protocol_headers = [
							[STATUS, response.status],
						]
						
						if length = response.body&.length
							protocol_headers << [CONTENT_LENGTH, length]
						end
						
						headers = ::Protocol::HTTP::Headers::Merged.new(
							protocol_headers,
							response.headers.header
						)
						
						if body = response.body and !head?
							stream = @connection.submit_response(@stream_id, headers, body)
							Output.new(stream, body).start
						else
							response.close
							@connection.submit_response(@stream_id, headers)
						end
					end
					
					private
					
					def enqueue!
						return if @enqueued
						
						@enqueued = true
						@connection.requests.enqueue(self)
					end
				end
			end
		end
	end
end
