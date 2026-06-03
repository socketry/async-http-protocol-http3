# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2026, by Samuel Williams.

source "https://rubygems.org"

gemspec

if File.directory?("../async-http")
	gem "async-http", path: "../async-http"
end

if File.directory?("../protocol-http3")
	gem "protocol-http3", path: "../protocol-http3"
else
	gem "protocol-http3", github: "socketry/protocol-http3"
end

gem "protocol-quic", github: "socketry/protocol-quic"

group :maintenance, optional: true do
	gem "bake-gem"
	gem "bake-modernize"
	gem "bake-releases"
	
	gem "decode"
	
	gem "utopia-project"
end

group :test do
	gem "sus"
	gem "sus-fixtures-async"
	gem "covered"
	
	gem "rubocop"
	gem "rubocop-md"
	gem "rubocop-socketry"
	
	gem "bake-test"
	gem "bake-test-external"
end
