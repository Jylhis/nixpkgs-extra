#!/usr/bin/env python3
"""Run the mem0 REST server: apply auth DB migrations, then serve with uvicorn."""

import os
import sys

APP_DIR = "@app@"


def main() -> None:
    # The server modules import each other by flat name, so run from their
    # directory. Telemetry is off by default; mem0 state goes to the systemd
    # state directory when there is one (mem0 otherwise writes ~/.mem0).
    os.chdir(APP_DIR)
    sys.path.insert(0, APP_DIR)
    os.environ.setdefault("MEM0_TELEMETRY", "false")
    if "STATE_DIRECTORY" in os.environ:
        os.environ.setdefault("MEM0_DIR", os.environ["STATE_DIRECTORY"])

    if os.environ.get("MEM0_SKIP_MIGRATIONS", "").lower() not in {"1", "true", "yes"}:
        from alembic.config import main as alembic_main

        alembic_main(argv=["-c", f"{APP_DIR}/alembic.ini", "upgrade", "head"])

    import uvicorn

    uvicorn.run(
        "main:app",
        host=os.environ.get("MEM0_HOST", "127.0.0.1"),
        port=int(os.environ.get("MEM0_PORT", "8888")),
    )


if __name__ == "__main__":
    main()
