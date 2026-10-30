"""房间号中转服务器（只用标准库）：房主和队友都连到这里，按房间号把 UDP 包原样转给对方。

服务器不跑物理，也不看包里是什么，ENet 的连接、重传都还是两边游戏自己做。

  端口 7777：队友连这里（他的 ENet 以为服务器就是房主）
  端口 7778：房主的 ENet 往这里发心跳，服务器从这个口把队友的包转给房主
             （房主那边看到的队友地址就是 服务器:7778）

控制包都以 MAGIC 开头，ENet 自己的包不会以它开头：
  -> 7777  REG                      <- ROOM <房间号> <口令>     （房主用临时 socket 申请房间）
  -> 7777  CHECK <房间号>           <- OK / NOROOM               （队友加入前先问一下房间在不在）
  -> 7777  JOIN <房间号>            （队友从自己 ENet 的 socket 发，服务器记下他的地址）
  -> 7778  HOST <房间号> <口令>     （房主从自己 ENet 的 socket 发，每几秒一次，顺便保持 NAT 映射）

运行：python relay.py [--port 7777]
"""

import argparse
import random
import secrets
import select
import socket
import time

MAGIC = b"\xffRIP "
ROOM_TTL = 30.0  # 房主这么久没心跳，房间作废
JOIN_TTL = 120.0  # 队友这么久没发包，忘掉他


class Room:
    def __init__(self, code: str, token: str):
        self.code = code
        self.token = token
        self.host = None  # 房主 ENet socket 在公网上的地址（从 7778 看到的）
        self.joiner = None  # 队友 ENet socket 在公网上的地址（从 7777 看到的）
        self.host_seen = time.monotonic()
        self.joiner_seen = 0.0


def log(*args):
    print(time.strftime("%m-%d %H:%M:%S"), *args, flush=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=7777)
    args = ap.parse_args()

    front = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)  # 队友这边
    front.bind(("0.0.0.0", args.port))
    back = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)  # 房主这边
    back.bind(("0.0.0.0", args.port + 1))
    for s in (front, back):
        s.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 1 << 20)
        if hasattr(socket, "SIO_UDP_CONNRESET"):
            # Windows：对方端口关掉后会收到 ICMP，recvfrom 会抛 10054，关掉这个行为
            s.ioctl(socket.SIO_UDP_CONNRESET, False)
    log("relay listening on UDP %d (joiners) / %d (hosts)" % (args.port, args.port + 1))

    rooms: dict[str, Room] = {}
    by_host: dict[tuple, Room] = {}
    by_joiner: dict[tuple, Room] = {}
    last_sweep = time.monotonic()

    def drop(room: Room, why: str):
        rooms.pop(room.code, None)
        by_host.pop(room.host, None)
        by_joiner.pop(room.joiner, None)
        log("room %s closed (%s)" % (room.code, why))

    def on_front(data: bytes, addr: tuple):
        room = by_joiner.get(addr)
        if room is not None and not data.startswith(MAGIC):
            room.joiner_seen = time.monotonic()
            if room.host is not None:
                back.sendto(data, room.host)
            return
        if not data.startswith(MAGIC):
            return  # 还没报房间号的陌生包（ENet 的连接请求会重发，不怕丢）
        parts = data[len(MAGIC):].decode("ascii", "replace").split()
        if not parts:
            return
        cmd = parts[0]
        if cmd == "REG":
            code = None
            for _ in range(50):
                c = "%04d" % random.randint(1000, 9999)
                if c not in rooms:
                    code = c
                    break
            if code is None:
                front.sendto(MAGIC + b"FULL", addr)
                return
            room = Room(code, secrets.token_hex(4))
            rooms[code] = room
            front.sendto(MAGIC + ("ROOM %s %s" % (code, room.token)).encode(), addr)
            log("room %s opened by %s:%d" % (code, *addr))
        elif cmd == "CHECK" and len(parts) >= 2:
            room = rooms.get(parts[1])
            ok = room is not None and room.host is not None
            front.sendto(MAGIC + (b"OK" if ok else b"NOROOM"), addr)
        elif cmd == "JOIN" and len(parts) >= 2:
            room = rooms.get(parts[1])
            if room is None:
                return
            if room.joiner != addr:
                by_joiner.pop(room.joiner, None)
                room.joiner = addr
                by_joiner[addr] = room
                log("room %s joined by %s:%d" % (room.code, *addr))
            room.joiner_seen = time.monotonic()

    def on_back(data: bytes, addr: tuple):
        room = by_host.get(addr)
        if data.startswith(MAGIC):
            parts = data[len(MAGIC):].decode("ascii", "replace").split()
            if len(parts) >= 3 and parts[0] == "HOST":
                r = rooms.get(parts[1])
                if r is None or r.token != parts[2]:
                    return
                if r.host != addr:
                    by_host.pop(r.host, None)
                    r.host = addr
                    by_host[addr] = r
                    log("room %s host at %s:%d" % (r.code, *addr))
                r.host_seen = time.monotonic()
            return
        if room is not None and room.joiner is not None:
            room.host_seen = time.monotonic()
            front.sendto(data, room.joiner)

    while True:
        ready, _, _ = select.select([front, back], [], [], 1.0)
        for s in ready:
            try:
                data, addr = s.recvfrom(65536)
            except OSError:
                continue
            (on_front if s is front else on_back)(data, addr)
        now = time.monotonic()
        if now - last_sweep > 5.0:
            last_sweep = now
            for room in list(rooms.values()):
                if now - room.host_seen > ROOM_TTL:
                    drop(room, "host gone")
                elif room.joiner is not None and now - room.joiner_seen > JOIN_TTL:
                    by_joiner.pop(room.joiner, None)
                    room.joiner = None


if __name__ == "__main__":
    main()
