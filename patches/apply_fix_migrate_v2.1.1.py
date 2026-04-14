#!/usr/bin/env python3
"""
Fix XC_VM v2.1.1 migrate bug.

Issue: /home/xc_vm/cli/migration_logic.php uses $_INFO['hostname'] etc.
without declaring `global $_INFO` — when included inside
MigrateCommand::execute() method scope, the variable is empty and PDO
falls back to localhost socket, producing:

    {"error":"MySQL: SQLSTATE[HY000] [2002] No such file or directory"}

Fix: prepend `global $_INFO, $db;` to the migration script body.

Idempotent — safe to re-run.
"""
import sys
from pathlib import Path

TARGET = Path("/home/xc_vm/cli/migration_logic.php")
MARKER = "global $_INFO, $db;"
ANCHOR = "// Requires admin.php already loaded, $db available"


def main() -> int:
    if not TARGET.exists():
        print(f"[skip] {TARGET} not found")
        return 0

    text = TARGET.read_text(encoding="utf-8")

    if MARKER in text:
        print("[ok] already patched")
        return 0

    if ANCHOR not in text:
        print(f"[err] anchor not found in {TARGET}")
        return 1

    patched = text.replace(ANCHOR, f"{ANCHOR}\n{MARKER}", 1)
    TARGET.write_text(patched, encoding="utf-8")
    print(f"[ok] patched {TARGET}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
