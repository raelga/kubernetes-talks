#!/usr/bin/env python3
"""Expose one loopback SSM port-forward as a hostname-preserving SOCKS5 proxy."""

import argparse
import select
import socket
import socketserver
import struct


class SocksServer(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True

    def __init__(self, address, host, port, forward_port):
        self.allowed_host = host.rstrip(".").lower()
        self.allowed_port = port
        self.forward_port = forward_port
        super().__init__(address, SocksHandler)


class SocksHandler(socketserver.BaseRequestHandler):
    def read_exact(self, size):
        result = bytearray()
        while len(result) < size:
            part = self.request.recv(size - len(result))
            if not part:
                raise ConnectionError("SOCKS client closed early")
            result.extend(part)
        return bytes(result)

    def reply(self, status):
        self.request.sendall(b"\x05" + bytes([status]) + b"\x00\x01\x7f\x00\x00\x01\x00\x00")

    def relay(self, upstream):
        sockets = [self.request, upstream]
        while sockets:
            readable, _, _ = select.select(sockets, [], [])
            for source in readable:
                data = source.recv(65536)
                peer = upstream if source is self.request else self.request
                if data:
                    peer.sendall(data)
                else:
                    try:
                        peer.shutdown(socket.SHUT_WR)
                    except OSError:
                        pass
                    sockets.remove(source)

    def handle(self):
        upstream = None
        try:
            version, method_count = self.read_exact(2)
            if version != 5:
                return
            if 0 not in self.read_exact(method_count):
                self.request.sendall(b"\x05\xff")
                return
            self.request.sendall(b"\x05\x00")

            version, command, reserved, address_type = self.read_exact(4)
            if version != 5 or reserved != 0 or command != 1:
                self.reply(7)
                return
            if address_type == 1:
                host = socket.inet_ntop(socket.AF_INET, self.read_exact(4))
            elif address_type == 3:
                host = self.read_exact(self.read_exact(1)[0]).decode("idna")
            elif address_type == 4:
                host = socket.inet_ntop(socket.AF_INET6, self.read_exact(16))
            else:
                self.reply(8)
                return
            port = struct.unpack("!H", self.read_exact(2))[0]
            if host.rstrip(".").lower() != self.server.allowed_host or port != self.server.allowed_port:
                self.reply(2)
                return

            upstream = socket.create_connection(("127.0.0.1", self.server.forward_port), timeout=15)
            upstream.settimeout(None)
            self.reply(0)
            self.relay(upstream)
        except (ConnectionError, OSError, UnicodeError, ValueError):
            try:
                if upstream is None:
                    self.reply(1)
            except OSError:
                pass
        finally:
            if upstream is not None:
                upstream.close()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--allowed-host", required=True)
    parser.add_argument("--allowed-port", type=int, default=3306)
    parser.add_argument("--forward-port", type=int, default=13306)
    parser.add_argument("--listen-port", type=int, default=1080)
    args = parser.parse_args()
    server = SocksServer(
        ("127.0.0.1", args.listen_port),
        args.allowed_host,
        args.allowed_port,
        args.forward_port,
    )
    try:
        server.serve_forever(poll_interval=0.25)
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
