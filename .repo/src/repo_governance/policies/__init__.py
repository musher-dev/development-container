"""Policy modules.

Each policy is a package with two files: `violations.py` declares the
failures it can report (including why each rule exists), and `check.py`
detects them. `run()` returns a `Report`.
"""
