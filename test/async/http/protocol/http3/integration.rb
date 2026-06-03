# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

require "async/http/protocol/http3/echo_server"
require "sus/fixtures/async/reactor_context"

describe Async::HTTP::Protocol::HTTP3 do
	with "an in-process echo server" do
		include Sus::Fixtures::Async::ReactorContext
		
		def timeout
			20
		end
		
		let(:server) {subject::Fixtures::EchoServerEndpoint.new(Async::Task.current)}
		
		after do
			server.close
		end
		
		it "handles a GET request" do
			status, body = server.with_client do |client|
				response = client.get("/hello")
				[response.status, response.read]
			end
			
			expect(status).to be == 200
			expect(body).to be == "GET /hello\n"
		end
		
		it "sends a POST request body" do
			payload = "the quick brown fox\n" * 8
			request_body = ::Protocol::HTTP::Body::Buffered.wrap(payload.dup)
			
			status, body = server.with_client do |client|
				response = client.post("/echo", [["content-type", "text/plain"]], request_body)
				[response.status, response.read]
			end
			
			expect(status).to be == 200
			expect(body).to be == payload
		end
		
		it "handles several sequential request lifecycles" do
			5.times do |index|
				status, body = server.with_client do |client|
					response = client.get("/seq/#{index}")
					[response.status, response.read]
				end
				
				expect(status).to be == 200
				expect(body).to be == "GET /seq/#{index}\n"
			end
		end
		
		it "reuses a client connection for sequential requests" do
			results = server.with_client do |client|
				2.times.map do |index|
					response = client.get("/reuse/#{index}")
					[response.status, response.read]
				end
			end
			
			expect(results).to be == [
				[200, "GET /reuse/0\n"],
				[200, "GET /reuse/1\n"],
			]
		end
		
		it "handles concurrent independent clients" do
			task = Async::Task.current
			results = 4.times.map do |index|
				task.async do
					status, body = server.with_client do |client|
						response = client.get("/c/#{index}")
						[response.status, response.read]
					end
					
					[index, status, body]
				end
			end.map(&:wait)
			
			results.each do |index, status, body|
				expect(status).to be == 200
				expect(body).to be == "GET /c/#{index}\n"
			end
		end
	end
end
