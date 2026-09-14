#!/usr/bin/env python3
"""Standalone test for the Skydroid/YunZhuo C12 gimbal "set IP" command.

Sends the same UDP frame that VideoManager::setC12CameraIp builds in the QGC
fork, so a successful run here means the STRATUM setting will also work on
this camera.

Frame layout (Skydroid TOP UDP, port 5000):

    #TPUD <LEN> w IPV <new_ip> <CHK>

where:
  - <LEN> is a single uppercase hex nibble = len(new_ip). IPv4 dotted-quad is
    7..15 chars so it always fits in one nibble.
  - <CHK> is (sum of all preceding bytes) & 0xFF as two uppercase hex chars.

Verified against the protocol doc example `#tpUDDwIPV192.168.31.22D7`
(sum=1495, 1495 & 0xFF = 0xD7).

Typical use:
    python set_c12_ip_test.py --new-ip 192.168.144.111
    python set_c12_ip_test.py --host 192.168.144.108 --new-ip 192.168.144.111 --lowercase

After a successful send the camera reboots and comes up on the new IP.
Ping the new address a few seconds later to confirm.
"""

from __future__ import annotations

import argparse
import ipaddress
import socket
import sys


def build_set_ip_frame(new_ip: str, lowercase_prefix: bool = False) -> bytes:
    ipaddress.IPv4Address(new_ip)  # raises ValueError on bad input
    ip_bytes = new_ip.encode("ascii")
    if not 7 <= len(ip_bytes) <= 15:
        raise ValueError(f"IP length {len(ip_bytes)} out of range 7..15")

    prefix = b"#tpUD" if lowercase_prefix else b"#TPUD"
    len_hex = format(len(ip_bytes), "X").encode("ascii")  # single nibble
    base = prefix + len_hex + b"wIPV" + ip_bytes
    chk = format(sum(base) & 0xFF, "02X").encode("ascii")
    return base + chk


def _self_test() -> None:
    expected = b"#tpUDDwIPV192.168.31.22D7"
    got = build_set_ip_frame("192.168.31.22", lowercase_prefix=True)
    assert got == expected, f"self-test failed: {got!r} != {expected!r}"


def main() -> int:
    _self_test()

    p = argparse.ArgumentParser(description="Send Skydroid IPV set-IP command to a C12 gimbal.")
    p.add_argument("--host", default="192.168.144.108",
                   help="Current camera IP (where to send the command). Default: 192.168.144.108")
    p.add_argument("--port", type=int, default=5000, help="UDP port. Default: 5000")
    p.add_argument("--new-ip", required=True, help="New IP to program into the camera (dotted-quad).")
    p.add_argument("--lowercase", action="store_true",
                   help="Use lowercase `#tpUD` prefix (matches the protocol doc example verbatim).")
    p.add_argument("--timeout", type=float, default=2.0, help="Seconds to wait for a reply. Default: 2.0")
    args = p.parse_args()

    try:
        frame = build_set_ip_frame(args.new_ip, lowercase_prefix=args.lowercase)
    except ValueError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    ipaddress.IPv4Address(args.host)  # sanity

    print(f"Target      : {args.host}:{args.port}")
    print(f"New IP      : {args.new_ip}")
    print(f"Frame (ASCII): {frame.decode('ascii')}")
    print(f"Frame (hex)  : {frame.hex(' ').upper()}")
    print(f"Frame length : {len(frame)} bytes")

    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.settimeout(args.timeout)
        sent = sock.sendto(frame, (args.host, args.port))
        print(f"Sent {sent} bytes.")
        try:
            data, addr = sock.recvfrom(1024)
            print(f"Reply from {addr[0]}:{addr[1]} ({len(data)} bytes):")
            try:
                print(f"  ASCII: {data.decode('ascii')}")
            except UnicodeDecodeError:
                pass
            print(f"  Hex  : {data.hex(' ').upper()}")
        except socket.timeout:
            print("No reply within timeout. This is normal for IPV — the camera "
                  "usually reboots straight into the new IP without acknowledging.")
            print(f"Try `ping {args.new_ip}` in a few seconds.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
