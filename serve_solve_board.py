#!/usr/bin/env python3
"""Serve workspace root with COOP/COEP headers and symlink support for bazel-bin."""
from __future__ import annotations

import http.server
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent

CROSS_ORIGIN_ISOLATION_HEADERS = {
    "Cross-Origin-Opener-Policy": "same-origin",
    "Cross-Origin-Embedder-Policy": "require-corp",
}


class SymlinkHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs) -> None:
        super().__init__(*args, directory=str(REPO_ROOT), **kwargs)

    def translate_path(self, path: str) -> str:
        # Strip query string and fragments
        path = path.split("?", 1)[0].split("#", 1)[0]
        trailing_slash = path.endswith("/")
        parts = [p for p in path.split("/") if p]

        res = REPO_ROOT
        for part in parts:
            if part in (".", ".."):
                continue
            res = res / part

        res_str = str(res)
        if trailing_slash and not res_str.endswith("/"):
            res_str += "/"
        return res_str

    def end_headers(self) -> None:
        for key, value in CROSS_ORIGIN_ISOLATION_HEADERS.items():
            self.send_header(key, value)
        super().end_headers()


def main() -> int:
    port = 8085
    server_address = ("127.0.0.1", port)
    httpd = http.server.ThreadingHTTPServer(server_address, SymlinkHTTPRequestHandler)
    print(f"Serving {REPO_ROOT} at http://127.0.0.1:{port}/solve_board.html")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nStopped.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
