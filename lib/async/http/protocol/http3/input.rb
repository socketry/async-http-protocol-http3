# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "protocol/http/body/writable"

module Async
	module HTTP
		module Protocol
			module HTTP3
				# A readable body backed by incoming HTTP/3 DATA chunks.
				class Input < ::Protocol::HTTP::Body::Writable
					# Initialize the input body.
					# @parameter length [Integer | Nil] The expected content length.
					def initialize(length = nil)
						super(length)
						
						@remaining = length
					end
					
					# Read the next available body chunk.
					# @returns [String | Nil] The next body chunk, or `nil` when complete.
					def read
						chunk = super
						
						if @remaining
							if chunk
								@remaining -= chunk.bytesize
							elsif @remaining > 0
								raise EOFError, "Expected #{self.length} bytes, #{@remaining} bytes short!"
							elsif @remaining < 0
								raise EOFError, "Expected #{self.length} bytes, #{@remaining} bytes over!"
							end
						end
						
						return chunk
					end
				end
			end
		end
	end
end
