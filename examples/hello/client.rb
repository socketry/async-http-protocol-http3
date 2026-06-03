#!/usr/bin/env ruby
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

# A minimal HTTP/3 "Hello World" client.
#
# This uses the high-level Async::HTTP::Client together with the HTTP/3
# endpoint and protocol adapter provided by this gem.
#
# Start the server first:
#
#   bundle exec ruby examples/hello/server.rb
#
# Then run the client:
#
#   bundle exec ruby examples/hello/client.rb

require "async"
require "async/http/client"
require "async/http/protocol/http3"
require "localhost"

module HelloWorld
	HOST = ENV.fetch("HOST", "localhost")
	PORT = ENV.fetch("PORT", "12345")
	
	# Build a client TLS context that trusts the self-signed `localhost` certificate.
	def self.client_context
		authority = Localhost::Authority.fetch("localhost")
		
		::Protocol::QUIC::TLS::ClientContext.new.tap do |context|
			context.add_protocol("h3")
			context.load_verify_file(authority.certificate_path) if context.respond_to?(:load_verify_file)
		end
	end
end

# The protocol instance owns the shared UDP transport and TLS configuration.
protocol = Async::HTTP::Protocol::HTTP3.new(client_context: HelloWorld.client_context)

# The endpoint resolves the URL to a UDP peer using the protocol above.
endpoint = Async::HTTP::Protocol::HTTP3::Endpoint.parse(
	"https://#{HelloWorld::HOST}:#{HelloWorld::PORT}",
	protocol: protocol,
)

Async do |task|
	$stderr.puts "HTTP/3 client connecting to #{HelloWorld::HOST}:#{HelloWorld::PORT}"
	
	client = Async::HTTP::Client.new(endpoint)
	
	task.with_timeout(10) do
		response = client.get("/")
		
		$stdout.puts "Response status: #{response.status}"
		response.headers.each do |name, value|
			$stdout.puts "  #{name}: #{value}"
		end
		$stdout.puts
		$stdout.write response.read
	end
ensure
	client&.close
end
