#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

# A minimal HTTP/3 "Hello World" server.
#
# This gem currently provides a high-level Async::HTTP *client* adapter. A
# high-level server adapter is not wired up yet, so this example uses the
# lower-level `protocol-http3` server/dispatcher building blocks directly.
#
# Run with:
#
#   bundle exec ruby examples/hello/server.rb
#
# Then, in another terminal:
#
#   bundle exec ruby examples/hello/client.rb

require "async"
require "localhost"
require "protocol/http/body/buffered"
require "protocol/http3"
require "socket"

module HelloWorld
	HOST = ENV.fetch("HOST", "localhost")
	PORT = ENV.fetch("PORT", "12345")
	
	# Resolve the local UDP address to bind to. We use AF_UNSPEC (matching the
	# client endpoint) so the server binds to the same address family the client
	# will connect to (e.g. IPv6 ::1 for "localhost").
	def self.address
		::Protocol::QUIC::Address.resolve(HOST, PORT, ::Socket::AF_UNSPEC, ::Socket::SOCK_DGRAM, ::Socket::AI_PASSIVE).first
	end
	
	# Build a server TLS context backed by the self-signed `localhost` certificate.
	def self.server_context
		authority = Localhost::Authority.fetch("localhost")
		
		::Protocol::QUIC::TLS::ServerContext.new.tap do |context|
			context.add_protocol("h3")
			context.load_certificate_file(authority.certificate_path)
			context.load_private_key_file(authority.key_path)
		end
	end
	
	# A tiny server that replies "Hello World!" to every request.
	class Server < ::Protocol::HTTP3::Server
		def initialize(...)
			super
			@request_headers = Hash.new{|hash, key| hash[key] = []}
		end
		
		def header_received(stream_id, name, value)
			@request_headers[stream_id] << [name, value]
		end
		
		def headers_finished(stream_id, is_final)
			return unless is_final
			
			$stdout.puts "Request headers:"
			@request_headers[stream_id].each do |name, value|
				$stdout.puts "  #{name}: #{value}"
			end
			
			body = "Hello World!\n"
			response_body = ::Protocol::HTTP::Body::Buffered.new([body])
			
			stream = submit_response(stream_id, [
				[":status", "200"],
				["server", "async-http-protocol-http3"],
				["content-type", "text/plain"],
				["content-length", body.bytesize.to_s],
			], response_body)
			
			Async::Task.current.async do
				stream.write_body(response_body)
			end
		end
	end
	
	# Creates a `Server` for each accepted QUIC connection.
	class Dispatcher < ::Protocol::HTTP3::Dispatcher
		def create_server(socket, address, packet_header)
			Server.new(self, configuration, tls_context, socket, address, packet_header, nil)
		end
	end
end

configuration = ::Protocol::QUIC::Configuration.new
socket = ::Protocol::QUIC::Socket.new(HelloWorld.address.family, ::Socket::SOCK_DGRAM, ::Socket::IPPROTO_UDP)
socket.bind(HelloWorld.address)

dispatcher = HelloWorld::Dispatcher.new(configuration, HelloWorld.server_context)

Async do
	$stderr.puts "HTTP/3 server listening on #{socket.local_address.inspect}"
	
	loop do
		dispatcher.receive(socket)
	end
ensure
	socket.close if socket.respond_to?(:close)
end
