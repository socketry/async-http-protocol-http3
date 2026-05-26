# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "socket"

require "async/http/protocol/configurable"
require "protocol/quic"

require_relative "http3/version"
require_relative "http3/client"
require_relative "http3/endpoint"

module Async
	module HTTP
		module Protocol
			# A stateful HTTP/3 protocol adapter for Async::HTTP.
			module HTTP3
				# Initialize a stateful HTTP/3 protocol adapter.
				def self.new(...)
					Instance.new(...)
				end
				
				# Build the default client TLS context.
				def self.client_context
					::Protocol::QUIC::TLS::ClientContext.new.tap do |context|
						context.add_protocol("h3")
					end
				end
				
				# @returns [Boolean] Whether the protocol supports bidirectional communication.
				def self.bidirectional?
					true
				end
				
				# @returns [Boolean] Whether the protocol supports trailers.
				def self.trailer?
					true
				end
				
				# Create a one-shot stateful protocol adapter and client.
				# @parameter peer [Endpoint::Peer] The HTTP/3 peer descriptor.
				def self.client(peer, **options)
					self.new(**options).client(peer)
				end
				
				# @returns [Array(String)] The supported ALPN names.
				def self.names
					["h3"]
				end
				
				# A stateful HTTP/3 protocol adapter for Async::HTTP.
				class Instance
					# Initialize the protocol adapter.
					# @parameter configuration [Protocol::QUIC::Configuration] The QUIC configuration.
					# @parameter client_context [Protocol::QUIC::TLS::ClientContext] The client TLS context.
					# @parameter local_address [Protocol::QUIC::Address | Nil] Optional local UDP bind address.
					def initialize(configuration: ::Protocol::QUIC::Configuration.new, client_context: nil, local_address: nil)
						@configuration = configuration
						@client_context = client_context || HTTP3.client_context
						@local_address = local_address
						
						@transport_mutex = Mutex.new
						@transport_socket = nil
						@transport_family = nil
						@transport_remote_data = nil
						@transport_references = 0
					end
					
					attr :configuration
					attr :client_context
					attr :local_address
					
					# @returns [Integer] The number of active sessions using the shared transport.
					def reference_count
						@transport_mutex.synchronize do
							@transport_references
						end
					end
					
					# @returns [Boolean] Whether the protocol supports bidirectional communication.
					def bidirectional?
						HTTP3.bidirectional?
					end
					
					# @returns [Boolean] Whether the protocol supports trailers.
					def trailer?
						HTTP3.trailer?
					end
					
					# Create a client session resource for the given peer descriptor.
					# @parameter peer [Endpoint::Peer] The HTTP/3 peer descriptor.
					def client(peer)
						Client.new(self, peer, acquire_transport(peer))
					end
					
					# @returns [Array(String)] The supported ALPN names.
					def names
						HTTP3.names
					end
					
					# Acquire the shared UDP transport for a client session.
					def acquire_transport(peer)
						@transport_mutex.synchronize do
							family = peer.remote_address.family
							
							if @transport_socket
								if @transport_family != family
									raise ArgumentError, "Cannot share HTTP/3 transport across address families."
								end
								
								if @transport_remote_data != peer.remote_address.data
									raise ArgumentError, "Cannot share HTTP/3 transport across remote addresses."
								end
							else
								@transport_socket = ::Protocol::QUIC::Socket.new(
									family,
									::Socket::SOCK_DGRAM,
									::Socket::IPPROTO_UDP
								)
								
								@transport_socket.bind(@local_address) if @local_address
								@transport_socket.connect(peer.remote_address)
								
								@transport_family = family
								@transport_remote_data = peer.remote_address.data
							end
							
							@transport_references += 1
							
							return @transport_socket
						end
					end
					
					# Release the shared UDP transport from a client session.
					def release_transport(socket)
						close_socket = nil
						
						@transport_mutex.synchronize do
							return unless @transport_socket.equal?(socket)
							
							@transport_references -= 1
							
							if @transport_references.zero?
								close_socket = @transport_socket
								
								@transport_socket = nil
								@transport_family = nil
								@transport_remote_data = nil
							elsif @transport_references.negative?
								raise RuntimeError, "Unbalanced HTTP/3 transport release."
							end
						end
						
						close_socket&.close if close_socket.respond_to?(:close)
					end
				end
			end
		end
	end
end
