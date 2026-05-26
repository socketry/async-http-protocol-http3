# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "uri"
require "socket"

require "protocol/quic"

module Async
	module HTTP
		module Protocol
			module HTTP3
				# A remote HTTP/3 peer descriptor.
				class Peer
					# Initialize the peer descriptor.
					# @parameter endpoint [Endpoint] The endpoint that created this peer.
					# @parameter remote_address [Protocol::QUIC::Address] The remote UDP address.
					def initialize(endpoint, remote_address)
						@endpoint = endpoint
						@remote_address = remote_address
					end
					
					attr :endpoint
					attr :remote_address
					
					# @returns [String] The peer hostname.
					def hostname
						@endpoint.hostname
					end
					
					# @returns [String] The authority for requests.
					def authority
						@endpoint.authority
					end
				end
				
				# An HTTP/3 endpoint that resolves to a UDP peer descriptor.
				class Endpoint
					# Parse an HTTP or HTTPS URL.
					# @parameter string [String] The URL to parse.
					# @parameter options [Hash] Additional endpoint options.
					def self.parse(string, **options)
						self.new(URI.parse(string).normalize, **options)
					end
					
					# Initialize the endpoint.
					# @parameter url [URI] The endpoint URL.
					# @parameter protocol [HTTP3] The default HTTP/3 protocol instance.
					def initialize(url, protocol: HTTP3.new, **options)
						raise ArgumentError, "URL must be absolute (include scheme, host): #{url}" unless url.absolute?
						
						@url = url
						@protocol = protocol
						@options = options
					end
					
					attr :url
					attr :protocol
					
					# @returns [String] The URL scheme.
					def scheme
						@options[:scheme] || @url.scheme
					end
					
					# @returns [Boolean] Whether this endpoint is secure.
					def secure?
						true
					end
					
					# @returns [String] The remote hostname.
					def hostname
						@options[:hostname] || @url.hostname
					end
					
					# @returns [Integer] The remote UDP port.
					def port
						@options[:port] || @url.port || 443
					end
					
					# @returns [String] The request authority.
					def authority(ignore_default_port = true)
						if ignore_default_port && port == 443
							@url.hostname
						else
							"#{@url.hostname}:#{port}"
						end
					end
					
					# Resolve and return a peer descriptor.
					def connect
						address = ::Protocol::QUIC::Address.resolve(
							hostname,
							port.to_s,
							::Socket::AF_UNSPEC,
							::Socket::SOCK_DGRAM,
							0
						).first
						
						Peer.new(self, address)
					end
					
					# @returns [String] A short endpoint representation.
					def to_s
						"\#<#{self.class} #{@url}>"
					end
					
					# @returns [String] A detailed endpoint representation.
					def inspect
						"\#<#{self.class} #{@url} #{@options.inspect}>"
					end
				end
			end
		end
	end
end
