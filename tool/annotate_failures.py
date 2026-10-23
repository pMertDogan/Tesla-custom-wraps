"""Turns a `flutter test --reporter expanded` log into workflow annotations.

GitHub keeps the raw log behind a download, which makes a red check on a pull
request hard to act on. This script prints one `::error` command per failing
test with the assertion around it, so the failure shows up on the pull request
itself.

    python3 tool/annotate_failures.py test.log
"""

import re
import sys

# How much of the log around a failure belongs to that failure.
CONTEXT_BEFORE = 2500
CONTEXT_AFTER = 400

# A workflow command message is a single line; newlines travel as %0A.
MAX_MESSAGE = 14000


def main(argv):
    if len(argv) < 2:
        return 0

    try:
        with open(argv[1], errors="ignore") as handle:
            log = handle.read()
    except OSError:
        return 0

    blocks = [
        log[max(0, match.start() - CONTEXT_BEFORE):match.end() + CONTEXT_AFTER]
        for match in re.finditer(r"\[E\]", log)
    ]
    text = "\n\n".join(blocks)[-MAX_MESSAGE:]
    if not text:
        return 0

    escaped = text.replace("%", "%25").replace("\r", "").replace("\n", "%0A")
    print("::error title=Test failures::" + escaped)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
