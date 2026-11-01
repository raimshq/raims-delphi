#!/usr/bin/env python3
"""Run the canonical SDK validator from the Raims Developer Toolkit."""
from pathlib import Path
import runpy
import sys

sys.dont_write_bytecode = True


def main():
    sdk = Path(__file__).resolve().parent.parent
    workspace = sdk.parent
    validator = workspace / "Developer-Toolkit/scripts/release-preflight/delphi_sdk.py"
    if not validator.is_file():
        raise RuntimeError("The canonical Developer Toolkit validator is unavailable.")
    sys.argv = [str(validator), "--source", str(sdk), "--workspace", str(workspace), *sys.argv[1:]]
    runpy.run_path(str(validator), run_name="__main__")


if __name__ == "__main__":
    main()
