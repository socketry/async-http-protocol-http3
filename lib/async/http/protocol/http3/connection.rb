# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "protocol/http/peer"

module Async
	module HTTP
		module Protocol
			module HTTP3
				HTTPS = "https".freeze
				SCHEME = ":scheme".freeze
				METHOD = ":method".freeze
				PATH = ":path".freeze
				AUTHORITY = ":authority".freeze
				STATUS = ":status".freeze
				
				CONTENT_LENGTH = "content-length".freeze
				
				VERSION_STRING = "HTTP/3"
				
				# Shared connection behaviour for HTTP/3 client and server connections.
				module Connection
					# Initialize connection state.
					def initialize(...)
						super
						
						@reader = nil
					end
					
					# Start the background UDP packet reader.
					def start_connection(socket = @socket, parent: Task.current)
						@reader || read_in_background(socket, parent: parent)
					end
					
					# Read packets until the QUIC connection closes.
					def read_in_background(socket = @socket, parent: Task.current)
						parent.async(transient: true) do |task|
							@reader = task
							
							task.annotate("#{version} reading packets for #{self.class}.")
							
							begin
								until closed?
									break if receive(socket) == false
									
									task.yield
								end
							rescue => error
								# Close with error below.
							ensure
								if @reader
									@reader = nil
									close(error)
								end
							end
						end
					end
					
					# Close the connection and stop the background reader.
					def close(error = nil)
						@closed = true
						
						if reader = @reader
							@reader = nil
							reader.stop(error)
						end
						
						super()
					end
					
					# @returns [Boolean] Whether this connection is closed.
					def closed?
						@closed
					end
					
					# @returns [Boolean] Whether this is an HTTP/1 connection.
					def http1?
						false
					end
					
					# @returns [Boolean] Whether this is an HTTP/2 connection.
					def http2?
						false
					end
					
					# @returns [Boolean] Whether this is an HTTP/3 connection.
					def http3?
						true
					end
					
					# @returns [Integer] The approximate maximum concurrent streams.
					def concurrency
						128
					end
					
					# @returns [Integer] The number of active streams on this connection.
					#   Required by the connection pool's usage accounting.
					def count
						0
					end
					
					# @returns [Boolean] Whether the connection can currently be used.
					def viable?
						!closed?
					end
					
					# @returns [Boolean] Whether the connection can be reused.
					def reusable?
						!closed?
					end
					
					# @returns [String] The HTTP version string.
					def version
						VERSION_STRING
					end
				end
			end
		end
	end
end
