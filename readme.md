# Async::HTTP::Protocol::HTTP3

Provides experimental HTTP/3 support for `async-http`.

## Usage

This package currently exposes explicit HTTP/3 client and server building blocks. Automatic `Alt-Svc` discovery and fallback are not implemented yet.

## Example

The `examples/hello` directory contains a minimal HTTP/3 server and client that exchange a `Hello World!` response over QUIC using a local self-signed certificate.

Start the server:

```bash
bundle exec ruby examples/hello/server.rb
```

In another terminal, run the client:

```bash
bundle exec ruby examples/hello/client.rb
```

By default both scripts use `localhost:12345`. You can override that with `HOST` and `PORT`:

```bash
HOST=localhost PORT=8443 bundle exec ruby examples/hello/server.rb
HOST=localhost PORT=8443 bundle exec ruby examples/hello/client.rb
```

## Releases

Please see the [project releases](https://github.com/socketry/async-http-protocol-http3/releases).
