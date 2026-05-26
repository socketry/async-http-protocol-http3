# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async/http/protocol/http3"

describe Async::HTTP::Protocol::HTTP3 do
	it "has a version" do
		expect(subject::VERSION).to be =~ /\d+\.\d+\.\d+/
	end
	
	it "creates a stateful protocol instance" do
		protocol = subject.new
		
		expect(protocol).to be_a(subject::Instance)
		expect(protocol.names).to be == ["h3"]
		expect(protocol.reference_count).to be == 0
	end
	
	with "an endpoint" do
		let(:endpoint) {subject::Endpoint.parse("https://localhost/")}
		
		it "uses a stateful protocol instance by default" do
			expect(endpoint.protocol).to be_a(subject::Instance)
		end
		
		it "retains the UDP transport while a client session is alive" do
			protocol = endpoint.protocol
			client = protocol.client(endpoint.connect)
			
			expect(protocol.reference_count).to be == 1
			
			client.close
			
			expect(protocol.reference_count).to be == 0
		end
	end
end
