"""Turns a `flutter test --reporter expanded` log into workflow annotations.

GitHub keeps the raw log behind a download, and the log of a large suite is
mostly progress lines. This script finds each failure, keeps the assertion and
the line of the test that raised it, and prints it as a workflow command so the
failure shows up on the pull request itself.

    python3 tool/annotate_failures.py test.log
"""

import re
import sys

# How much of the exception is quoted: enough for "Expected/Actual" plus a
# stack frame, short enough to stay readable in the annotation panel.
EXCEPTION_WINDOW = 1200

# Workflow commands are one line per message; newlines travel as %0A.
MAX_MESSAGE = 12000


def _escape(text):
    return text.replace("%", "%25").replace("\r", "").replace("\n", "%0A")


def failures(log):
    """One short report per failed test, in the order they appear."""
    reports = []
    for match in re.finditer(r"\[E\]", log):
        error_line = log[log.rfind("\n", 0, match.start()) + 1:match.start() + 3]
        name = error_line.split(": ", 1)[-1].strip() if ": " in error_line else ""

        window = log[max(0, match.start() - 6000):match.start()]
        start = window.rfind("EXCEPTION CAUGHT")
        body = window[start:] if start >= 0 else window
        # Keep the assertion, not the widget dump above it.
        for marker in ("The following TestFailure was thrown", "The following"):
            index = body.find(marker)
            if index >= 0:
                body = body[index:]
                break
        body = body[:EXCEPTION_WINDOW].strip()

        lines = body.splitlines()
        location = ""
        for line in lines:
            found = re.search(r"file:///\S+_test\.dart:(\d+):(\d+)", line)
            if found:
                location = line.strip().lstrip("#").strip()
                break

        report = name
        if location:
            report += "\n  at " + location
        if body:
            report += "\n" + body
        reports.append(report)

    # Dedupe: the same test can be reported twice (progress line + summary).
    seen = set()
    unique = []
    for report in reports:
        key = report.splitlines()[0]
        if key in seen:
            continue
        seen.add(key)
        unique.append(report)
    return unique


def main(argv):
    if len(argv) < 2:
        return 0

    try:
        with open(argv[1], errors="ignore") as handle:
            log = handle.read()
    except OSError:
        return 0

    for report in failures(log):
        print("::error title=Test failure::" + _escape(report[:MAX_MESSAGE]))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
