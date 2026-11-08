#!/usr/bin/env python3
# emoji-insert.py TEXT - puts TEXT into the text field that has the keyboard focus, the
# way an input method (fcitx5, IBus) puts in what you type: through Wayland's
# input-method-v2, which Hyprland hands on to the app (text-input-v3: GTK and Qt apps,
# Firefox, kitty ...). The emoji picker (modules/EmojiPicker.qml, scripts/emoji.sh)
# uses it for the emoji you pick.
#
# Only into a text field: the app tells Hyprland when one has the focus, and only then
# is the text put in.
#
# Exit status:
#   0  put in
#   1  no text field has the focus - or the app does not say (apps without input
#      method support: Electron apps such as VS Code or Discord, X11 apps)
#   2  not possible here: no Wayland, no input method support in the compositor, or
#      another input method (fcitx5, IBus) is running
#
# Needs nothing but Python: it speaks the few Wayland messages it needs itself.
import os
import select
import socket
import struct
import sys
import time

WAIT = 0.4      # seconds the app gets to say that a text field has the focus


class Wayland:
    """a bare Wayland connection: send requests, read events"""

    def __init__(self):
        name = os.environ.get("WAYLAND_DISPLAY") or "wayland-0"
        path = name if name.startswith("/") else os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), name)
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.connect(path)
        self.buf = b""
        self.last_id = 1            # 1 is wl_display

    def new_id(self):
        self.last_id += 1
        return self.last_id

    def send(self, obj, opcode, *args):
        """a request: ints are uint / object / new_id arguments, str are strings"""
        body = b""
        for a in args:
            if isinstance(a, str):
                s = a.encode("utf-8", "surrogateescape") + b"\0"
                body += struct.pack("=I", len(s)) + s + b"\0" * (-len(s) % 4)
            else:
                body += struct.pack("=I", a)
        self.sock.sendall(struct.pack("=II", obj, (8 + len(body)) << 16 | opcode) + body)

    def events(self, seconds):
        """the events that come within `seconds`: (object, opcode, arguments)"""
        deadline = time.monotonic() + seconds
        while True:
            while len(self.buf) >= 8:
                obj, word = struct.unpack_from("=II", self.buf)
                size = word >> 16
                if size < 8:
                    raise OSError("broken message")
                if len(self.buf) < size:
                    break
                body, self.buf = self.buf[8:size], self.buf[size:]
                yield obj, word & 0xFFFF, body
            left = deadline - time.monotonic()
            if left <= 0 or not select.select([self.sock], [], [], left)[0]:
                return
            data = self.sock.recv(65536)
            if not data:
                raise OSError("the compositor closed the connection")
            self.buf += data


def string_at(body, offset):
    """a string argument: (text, offset after it)"""
    n = struct.unpack_from("=I", body, offset)[0]
    text = body[offset + 4:offset + 4 + max(0, n - 1)].decode("utf-8", "replace")
    return text, offset + 4 + n + (-n % 4)


def insert(text):
    wl = Wayland()
    display = 1

    # the globals: the seat and the input method manager
    registry = wl.new_id()
    wl.send(display, 1, registry)               # wl_display.get_registry
    sync = wl.new_id()
    wl.send(display, 0, sync)                   # wl_display.sync
    globals_ = {}
    synced = False
    for obj, op, body in wl.events(2):
        if obj == registry and op == 0:         # wl_registry.global (name, interface, version)
            name = struct.unpack_from("=I", body)[0]
            interface, _ = string_at(body, 4)
            globals_.setdefault(interface, name)
        elif obj == sync and op == 0:           # wl_callback.done
            synced = True
            break
        elif obj == display and op == 0:        # wl_display.error
            return 2
    if not synced or "wl_seat" not in globals_ or "zwp_input_method_manager_v2" not in globals_:
        return 2

    # wl_registry.bind (name, interface, version, new id)
    seat = wl.new_id()
    wl.send(registry, 0, globals_["wl_seat"], "wl_seat", 1, seat)
    manager = wl.new_id()
    wl.send(registry, 0, globals_["zwp_input_method_manager_v2"], "zwp_input_method_manager_v2", 1, manager)
    # zwp_input_method_manager_v2.get_input_method (seat, new id): we are the input method now -
    # the compositor tells the focused app, and the app says whether a text field has the focus
    im = wl.new_id()
    wl.send(manager, 0, seat, im)

    active = pending = False
    serial = 0                                  # the number of "done" events, for commit
    for obj, op, body in wl.events(WAIT):
        if obj == display and op == 0:
            return 2
        if obj != im:
            continue
        if op == 0:                             # activate: a text field has the focus
            pending = True
        elif op == 1:                           # deactivate
            pending = False
        elif op == 5:                           # done: the state above applies
            serial += 1
            active = pending
            if active:
                break
        elif op == 6:                           # unavailable: another input method is running
            return 2
    if not active:
        return 1

    wl.send(im, 0, text)                        # zwp_input_method_v2.commit_string
    wl.send(im, 3, serial)                      # zwp_input_method_v2.commit
    done = wl.new_id()
    wl.send(display, 0, done)                   # wait until the compositor has it
    for obj, op, body in wl.events(1):
        if obj == done and op == 0:
            break
    wl.send(im, 6)                              # zwp_input_method_v2.destroy
    return 0


def main():
    if len(sys.argv) < 2 or not sys.argv[1]:
        print("usage: emoji-insert.py TEXT", file=sys.stderr)
        return 2
    try:
        return insert(sys.argv[1])
    except (OSError, struct.error, ValueError):
        return 2


sys.exit(main())
