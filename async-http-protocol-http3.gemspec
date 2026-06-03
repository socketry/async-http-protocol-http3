# frozen_string_literal: true

require_relative "lib/async/http/protocol/http3/version"

Gem::Specification.new do |spec|
	spec.name = "async-http-protocol-http3"
	spec.version = Async::HTTP::Protocol::HTTP3::VERSION
	
	spec.summary = "HTTP/3 protocol adapter for Async::HTTP."
	spec.authors = ["Samuel Williams"]
	spec.license = "MIT"
	
	spec.cert_chain  = ["release.cert"]
	spec.signing_key = File.expand_path("~/.gem/release.pem")
	
	spec.homepage = "https://github.com/socketry/async-http-protocol-http3"
	
	spec.metadata = {
		"documentation_uri" => "https://socketry.github.io/async-http-protocol-http3/",
		"source_code_uri" => "https://github.com/socketry/async-http-protocol-http3.git",
		"funding_uri" => "https://github.com/sponsors/ioquatix",
	}
	
	spec.files = Dir["{examples,lib}/**/*", "*.md", base: __dir__]
	spec.require_paths = ["lib"]
	
	spec.required_ruby_version = ">= 3.3"
	
	spec.add_dependency "async-http", "~> 0.95"
	spec.add_dependency "protocol-http3", "~> 0.0.1"
end
