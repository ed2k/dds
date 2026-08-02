"""System test: verify DDS WASM JS API under Node.js."""
from __future__ import annotations

import os
import shutil
import subprocess
import unittest
from pathlib import Path


def _runfiles_root() -> Path:
    for key in ("RUNFILES_DIR", "TEST_SRCDIR"):
        if key in os.environ:
            return Path(os.environ[key])
    raise RuntimeError("not running under Bazel test")


def rlocation(relpath: str) -> Path:
    root = _runfiles_root()
    for candidate in (root / relpath, root / "_main" / relpath):
        if candidate.exists():
            return candidate
    raise FileNotFoundError(relpath)


@unittest.skipUnless(shutil.which("node"), "node not found")
class DdsWasmApiTest(unittest.TestCase):
    def test_dds_wasm_api_node(self) -> None:
        js = rlocation("wasm/dds_wasm_api.js")
        test_cjs = rlocation("wasm/tests/dds_wasm_api_test.cjs")

        proc = subprocess.run(
            ["node", str(test_cjs), str(js)],
            capture_output=True,
            text=True,
            check=False,
            timeout=120,
            cwd=str(js.parent),
        )
        self.assertEqual(
            proc.returncode,
            0,
            msg=f"stdout:\n{proc.stdout}\nstderr:\n{proc.stderr}",
        )
        self.assertIn("All WASM JS API tests passed successfully!", proc.stdout)


if __name__ == "__main__":
    unittest.main()
