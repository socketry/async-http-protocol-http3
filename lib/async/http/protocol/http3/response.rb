# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async/notification"
require "protocol/http/headers"

require "async/http/protocol/response"

require_relative "connection"
require_relative "input"
require_relative "output"

module Async
	module HTTP
		module Protocol
			module HTTP3
				# An HTTP/3 response received by a client.
				class Response < Protocol::Response
					# Initialize the pending response.
					# @parameter connection [Client] The HTTP/3 client connection.
					# @parameter request [Protocol::HTTP::Request] The original request.
					def initialize(connection, request)
						super(connection.version, nil, nil)
						
						@connection = connection
						@request = request
						@stream = nil
						
						@raw_headers = []
						@notification = Async::Notification.new
						@exception = nil
						@length = nil
					end
					
					attr :request
					attr :stream
					
					# Attach the native HTTP/3 stream used for this response.
					def stream=(stream)
						@stream = stream
					end
					
					# @returns [Connection] The underlying HTTP/3 connection.
					def connection
						@connection
					end
					
					# Assign the connection pool. HTTP/3 pools retain the connection until closed.
					def pool=(pool)
						@pool = pool
					end
					
					# Wait for final response headers.
					def wait
						@notification&.wait
						
						raise @exception if @exception
					end
					
					# Receive a response header.
					def header_received(name, value)
						@raw_headers << [name, value]
					end
					
					# Finish the current response headers.
					def headers_finished(is_final)
						unless is_final
							return receive_interim_headers
						end
						
						headers = @raw_headers
						@raw_headers = []
						
						status_header = headers.shift
						
						unless status_header&.first == STATUS
							raise ::Protocol::HTTP::HeaderError, "Invalid response headers: #{headers.inspect}"
						end
						
						@status = Integer(status_header.last)
						@headers = ::Protocol::HTTP::Headers.new
						
						headers.each do |key, value|
							if key == CONTENT_LENGTH
								@length = Integer(value)
							else
								@headers.add(key, value)
							end
						end
						
						@body = Input.new(@length)
						
						notify!
					rescue => error
						close(error)
					end
					
					# Receive an HTTP/3 body chunk.
					def data_received(chunk)
						body.write(chunk)
					end
					
					# Finish the response body.
					def stream_finished
						body&.close_write
					end
					
					# Close the response stream.
					def close(error = nil)
						@exception ||= error
						body&.close_write(error)
						notify!
					end
					
					# Start writing the request body.
					def write_request_body(body)
						Output.new(@stream, body).start
					end
					
					private
					
					def receive_interim_headers
						headers = @raw_headers
						@raw_headers = []
						
						status_header = headers.shift
						
						if status_header&.first == STATUS
							@request.send_interim_response(Integer(status_header.last), ::Protocol::HTTP::Headers[headers])
						end
					end
					
					def notify!
						if notification = @notification
							@notification = nil
							notification.signal
						end
					end
				end
			end
		end
	end
end
