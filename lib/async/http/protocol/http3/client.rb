# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async/notification"
require "protocol/http/headers"
require "protocol/http3"

require_relative "connection"
require_relative "response"

module Async
	module HTTP
		module Protocol
			module HTTP3
				# An Async::HTTP compatible HTTP/3 client session.
				class Client < ::Protocol::HTTP3::Client
					include Connection
					
					# Initialize the client session.
					# @parameter protocol [HTTP3] The owning protocol instance.
					# @parameter peer [Peer] The remote peer descriptor.
					# @parameter socket [Protocol::QUIC::Socket] The UDP socket.
					def initialize(protocol, peer, socket)
						@protocol = protocol
						@peer = peer
						@socket = socket
						@responses = {}
						@handshake = Async::Notification.new
						@ready = false
						@started = false
						@closed = false
						@released = false
						
						super(protocol.configuration, protocol.client_context, socket, peer.remote_address, 1)
					end
					
					attr :peer
					
					# Called when the QUIC/TLS handshake completes.
					def handshake_completed
						@ready = true
						@handshake&.signal
					end
					
					# Submit a request and return the response.
					# @parameter request [Protocol::HTTP::Request] The request to send.
					# @returns [Protocol::HTTP::Response] The response.
					def call(request)
						wait_until_ready
						
						response = Response.new(self, request)
						headers = request_headers(request)
						stream = submit_request(headers, request.body)
						response.stream = stream
						@responses[stream.stream_id] = response
						
						response.write_request_body(request.body) if request.body
						response.wait
						
						return response
					end
					
					# @returns [Integer] The current multiplexing capacity.
					def concurrency
						128
					end
					
					# Receive a response header.
					def header_received(stream_id, name, value)
						@responses[stream_id]&.header_received(name, value)
					end
					
					# Finish response headers.
					def headers_finished(stream_id, is_final)
						@responses[stream_id]&.headers_finished(is_final)
					end
					
					# Receive response body data.
					def data_received(stream_id, chunk)
						@responses[stream_id]&.data_received(chunk)
					end
					
					# Finish a response body stream.
					def stream_finished(stream_id)
						if response = @responses.delete(stream_id)
							response.stream_finished
						end
					end
					
					# Close the client session.
					def close(error = nil)
						@responses.each_value do |response|
							response.close(error)
						end
						
						@responses.clear
						
						if @started
							super
						else
							@closed = true
						end
					ensure
						release_transport
					end
					
					private
					
					def wait_until_ready
						return if @ready
						
						unless @started
							@started = true
							
							send_packets
							start_connection(@socket)
						end
						
						@handshake&.wait unless @ready
					end
					
					def release_transport
						return if @released
						
						@released = true
						@protocol.release_transport(@socket)
					end
					
					def request_headers(request)
						# The native HTTP/3 binding expects a flat Array of
						# [name, value] String pairs, so we build one explicitly
						# rather than passing a Headers wrapper object.
						headers = [
							[SCHEME, (request.scheme || HTTPS).to_s],
							[METHOD, request.method.to_s],
						]
						
						if path = request.path
							headers << [PATH, path.to_s]
						end
						
						if authority = request.authority || @peer.authority
							headers << [AUTHORITY, authority.to_s]
						end
						
						if length = request.body&.length
							headers << [CONTENT_LENGTH, length.to_s]
						end
						
						request.headers.each do |name, value|
							headers << [name.to_s, value.to_s]
						end
						
						headers
					end
				end
			end
		end
	end
end
