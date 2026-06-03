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
						
						@pool = nil
						@finished = false
						@output = nil
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
					
					# Assign the connection pool, releasing the connection back to the
					# pool once the response stream has finished.
					def pool=(pool)
						if @finished
							pool.release(@connection)
						else
							@pool = pool
						end
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
					#
					# @parameter is_final [Boolean] Whether the stream ends after these
					#   headers (i.e. there is no response body).
					def headers_finished(is_final)
						headers = @raw_headers
						@raw_headers = []
						
						status_header = headers.shift
						
						unless status_header&.first == STATUS
							raise ::Protocol::HTTP::HeaderError, "Invalid response headers: #{headers.inspect}"
						end
						
						status = Integer(status_header.last)
						
						# Interim (1xx) responses precede the final response and never
						# carry a body. They are delivered as a separate header block.
						if status >= 100 && status < 200
							@request.send_interim_response(status, ::Protocol::HTTP::Headers[headers])
							return
						end
						
						@status = status
						@headers = ::Protocol::HTTP::Headers.new
						
						headers.each do |key, value|
							if key == CONTENT_LENGTH
								@length = Integer(value)
							else
								@headers.add(key, value)
							end
						end
						
						@body = Input.new(@length)
						
						# If the stream is already finished (no body), close the read
						# side immediately so consumers observe a complete empty body.
						@body.close_write if is_final
						
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
						release!
					end
					
					# Close the response stream.
					def close(error = nil)
						@exception ||= error
						body&.close_write(error)
						notify!
						release!
					end
					
					# Start writing the request body.
					def write_request_body(body)
						@output = Output.new(@stream, body)
						@output.start
					end
					
					private
					
					def notify!
						if notification = @notification
							@notification = nil
							notification.signal
						end
					end
					
					# Release the underlying connection back to the pool exactly once.
					def release!
						return if @finished
						@finished = true
						
						@output&.wait
						
						if pool = @pool
							@pool = nil
							pool.release(@connection)
						end
					end
				end
			end
		end
	end
end
