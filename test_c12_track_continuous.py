#!/usr/bin/env python3
"""Standalone continuous-track tester for the Skydroid/YunZhuo C12 gimbal.

The Stratum in-app tracker sends `SUM 01` (arm tracker) once and then a single
`GOT x y` (feed target) each time the user taps. That works if the camera is
happy to hold the last target forever, but on some C12 firmware the tracker
loses lock unless the target is re-injected periodically. This script lets us
poke at that hypothesis without rebuilding the app.

Frames (see the Skydroid TOP UDP protocol, port 5000):
    Arm tracker : #TPUG2wSUM0162
    Feed target : #TPUG8wGOT<x_hex><y_hex><CHK>
        - x is 4 uppercase-hex chars, 0..0500 (1280)
        - y is 4 uppercase-hex chars, 0..02D0 (720)
        - CHK is (sum of all preceding bytes) & 0xFF, 2 uppercase-hex chars

Typical use (camera at 192.168.144.108, target near centre of a 1280x720 frame):
    python test_c12_track_continuous.py --x 640 --y 360
    python test_c12_track_continuous.py --host 192.168.144.109 --x 640 --y 360 --rate 20
    python test_c12_track_continuous.py --x 640 --y 360 --duration 5

Ctrl-C to stop early. On exit the script sends `SUM 00` to disarm the tracker.
"""

from __future__ import annotations

import argparse
import ipaddress
import select
import socket
import sys
import time

ARM_TRACKER = b"#TPUG2wSUM0162"
DISARM_TRACKER = b"#TPUG2wSUM0061"


def build_got_frame(x: int, y: int) -> bytes:
    if not 0 <= x <= 0xFFFF or not 0 <= y <= 0xFFFF:
        raise ValueError(f"x/y out of 16-bit range: {x}, {y}")
    base = b"#TPUG8wGOT" + f"{x:04X}{y:04X}".encode("ascii")
    chk = format(sum(base) & 0xFF, "02X").encode("ascii")
    return base + chk


def _self_test() -> None:
    # 640, 360 → 0280, 0168 → same as VideoManager::sendCameraTrackPoint pattern.
    got = build_got_frame(640, 360)
    assert got == b"#TPUG8wGOT0280016895", f"self-test failed: {got!r}"


def _drain(sock: socket.socket) -> None:
    while True:
        r, _, _ = select.select([sock], [], [], 0)
        if not r:
            return
        try:
            data, addr = sock.recvfrom(1024)
        except OSError:
            return
        try:
            ascii_ = data.decode("ascii")
        except UnicodeDecodeError:
            ascii_ = "<non-ascii>"
        print(f"  <- {addr[0]}:{addr[1]}  {ascii_}  (hex {data.hex(' ').upper()})")


def main() -> int:
    _self_test()

    p = argparse.ArgumentParser(description="Continuously send C12 tracking GOT frames.")
    p.add_argument("--host", default="192.168.144.108", help="Camera IP. Default: 192.168.144.108")
    p.add_argument("--port", type=int, default=5000, help="UDP port. Default: 5000")
    p.add_argument("--x", type=int, required=True, help="Target x in pixels (0..1280 for the C12 stream).")
    p.add_argument("--y", type=int, required=True, help="Target y in pixels (0..720 for the C12 stream).")
    p.add_argument("--rate", type=float, default=10.0, help="Send rate in Hz. Default: 10")
    p.add_argument("--duration", type=float, default=0.0, help="Seconds to run. 0 = until Ctrl-C. Default: 0")
    p.add_argument("--no-arm", action="store_true",
                   help="Skip the initial SUM 01 (assume tracker already armed).")
    p.add_argument("--no-disarm", action="store_true", help="Skip the SUM 00 on exit.")
    args = p.parse_args()

    ipaddress.IPv4Address(args.host)
    if not 1 <= args.rate <= 200:
        print("ERROR: --rate must be in 1..200", file=sys.stderr)
        return 2
    x = max(0, min(args.x, 1280))
    y = max(0, min(args.y, 720))
    frame = build_got_frame(x, y)
    period = 1.0 / args.rate

    print(f"Target      : {args.host}:{args.port}")
    print(f"Point       : x={x} y={y}  ({x:04X},{y:04X})")
    print(f"GOT frame   : {frame.decode('ascii')}   ({len(frame)} bytes)")
    print(f"Rate        : {args.rate:g} Hz  (period {period*1000:.1f} ms)")
    print(f"Duration    : {'unlimited' if args.duration == 0 else f'{args.duration:g} s'}")
    print()

    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.setblocking(False)
        sock.bind(("0.0.0.0", 0))
        _, local_port = sock.getsockname()
        print(f"Bound local UDP port {local_port}. Any replies from the camera will "
              f"show up as `<- host:port  ascii  (hex ...)` lines.")

        if not args.no_arm:
            print(f"-> ARM  {ARM_TRACKER.decode('ascii')}")
            sock.sendto(ARM_TRACKER, (args.host, args.port))
            time.sleep(0.05)
            _drain(sock)

        sent = 0
        start = time.monotonic()
        next_tick = start
        try:
            while True:
                now = time.monotonic()
                if args.duration > 0 and now - start >= args.duration:
                    break
                if now < next_tick:
                    time.sleep(min(period, next_tick - now))
                    continue
                sock.sendto(frame, (args.host, args.port))
                sent += 1
                if sent == 1 or sent % max(1, int(args.rate)) == 0:
                    print(f"-> GOT  {frame.decode('ascii')}   (#{sent}, t={now - start:5.2f} s)")
                _drain(sock)
                next_tick += period
        except KeyboardInterrupt:
            print("\nInterrupted.")
        finally:
            elapsed = time.monotonic() - start
            print(f"\nSent {sent} GOT frames in {elapsed:.2f} s "
                  f"(effective rate {sent / elapsed if elapsed > 0 else 0:.1f} Hz).")
            if not args.no_disarm:
                print(f"-> DIS  {DISARM_TRACKER.decode('ascii')}")
                try:
                    sock.sendto(DISARM_TRACKER, (args.host, args.port))
                    time.sleep(0.1)
                    _drain(sock)
                except OSError as exc:
                    print(f"  (disarm send failed: {exc})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
