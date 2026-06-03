# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async"
require "async/http/client"
require "async/http/protocol/http3"
require "localhost"
require "protocol/http/body/buffered"
require "socket"

module Async
	module HTTP
		module Protocol
			module HTTP3
				module Fixtures
					HOST = "localhost"
					
					def self.server_context
						authority = Localhost::Authority.fetch("localhost")
						
						::Protocol::QUIC::TLS::ServerContext.new.tap do |context|
							context.add_protocol("h3")
							context.load_certificate_file(authority.certificate_path)
							context.load_private_key_file(authority.key_path)
						end
					end
					
					def self.client_context
						::Protocol::QUIC::TLS::ClientContext.new.tap do |context|
							context.add_protocol("h3")
						end
					end
					
					# An echo server: replies with the request body, or "GET <path>" for empty bodies.
					class EchoServer < ::Protocol::HTTP3::Server
						def initialize(...)
							super
							
							@method = {}
							@path = {}
							@body = Hash.new{|hash, key| hash[key] = String.new}
							@responded = {}
						end
						
						def header_received(stream_id, name, value)
							@method[stream_id] = value if name == ":method"
							@path[stream_id] = value if name == ":path"
						end
						
						def headers_finished(stream_id, is_final)
							respond(stream_id) if is_final
						end
						
						def data_received(stream_id, chunk)
							@body[stream_id] << chunk
						end
						
						def stream_finished(stream_id)
							respond(stream_id)
						end
						
						def respond(stream_id)
							return if @responded[stream_id]
							@responded[stream_id] = true
							
							payload = @body[stream_id]
							payload = "#{@method[stream_id]} #{@path[stream_id]}\n" if payload.empty?
							
							response_body = ::Protocol::HTTP::Body::Buffered.new([payload])
							stream = submit_response(stream_id, [
								[":status", "200"],
								["content-type", "text/plain"],
								["content-length", payload.bytesize.to_s],
							], response_body)
							
							Async::Task.current.async do
								stream.write_body(response_body)
							end
						end
					end
					
					class Dispatcher < ::Protocol::HTTP3::Dispatcher
						def create_server(socket, address, packet_header)
							EchoServer.new(self, configuration, tls_context, socket, address, packet_header, nil)
						end
					end
					
					# Runs an in-process HTTP/3 echo server bound to an ephemeral UDP port.
					class EchoServerEndpoint
						def initialize(task, host: HOST, port: "0")
							@host = host
							
							address = ::Protocol::QUIC::Address.resolve(host, port, ::Socket::AF_UNSPEC, ::Socket::SOCK_DGRAM, ::Socket::AI_PASSIVE).first
							@socket = ::Protocol::QUIC::Socket.new(address.family, ::Socket::SOCK_DGRAM, ::Socket::IPPROTO_UDP)
							@socket.bind(address)
							
							@port, = ::Socket.unpack_sockaddr_in(@socket.local_address.data)
							@dispatcher = Dispatcher.new(::Protocol::QUIC::Configuration.new, Fixtures.server_context)
							
							@server_task = task.async do
								loop do
									@dispatcher.receive(@socket)
								end
							end
						end
						
						attr :host
						attr :port
						
						def close
							@server_task&.stop
							@socket&.close if @socket.respond_to?(:close)
						end
						
						def with_client
							protocol = Async::HTTP::Protocol::HTTP3.new(client_context: Fixtures.client_context)
							endpoint = Async::HTTP::Protocol::HTTP3::Endpoint.parse("https://#{@host}:#{@port}", protocol: protocol)
							client = Async::HTTP::Client.new(endpoint)
							
							begin
								yield client
							ensure
								client.close
							end
						end
					end
				end
			end
		end
	end
end
