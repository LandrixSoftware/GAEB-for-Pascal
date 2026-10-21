#!/usr/bin/env python3
"""Check Pascal sources for language features and units that Delphi 6 lacks.

Rules: the same language subset as LandrixXml (see CONTRIBUTING.md). Exits with code 1 if any violation is
found, 0 otherwise.

A line may opt out of the identifier checks with the marker comment
``// check-forbidden: allow`` (only for conditional compatibility code, e.g.
``NativeInt`` inside a ``{$IF CompilerVersion >= 20.0}`` branch).

API levels: every unit in source/ carries one marker comment
``{ API: stable.`` or ``{ API: internal.`` before its unit line, and the
interface section of a stable unit uses only stable units of this library
(internal units may change in any release, so a stable signature must not
depend on them).

Usage: python tools/check-forbidden.py [path ...]
Default paths: source, tests, examples.
"""

import os
import re
import sys

ALLOW_MARKER = "check-forbidden: allow"
EXTENSIONS = (".pas", ".inc", ".dpr", ".lpr")

# types: Delphi 13 needs it for TList.TDirection (hint H2443 at inherited Extract)
ALLOWED_UNITS = {"sysutils", "classes", "contnrs", "types"}
# Only in programs (.dpr/.lpr), never in library units: cwstring installs the
# Unix wide string manager that applications need for lossless conversions.
PROGRAM_UNITS = {"cwstring"}
OWN_UNIT_PREFIXES = ("landrixxml", "landrixgaeb")

FORBIDDEN_IDENTIFIERS = [
    "TStringBuilder", "TEncoding", "TFormatSettings", "PosEx", "CharInSet",
    "RawByteString", "NativeInt", "NativeUInt", "TBytes", "UInt64",
    "UTF8ToString",
]

# (regex on comment-free code, message)
FORBIDDEN_PATTERNS = [
    (r"\bfor\s+(var\s+)?\w+\s+in\b", "for ... in"),
    (r"\bExit\s*\(", "Exit(Value)"),
    (r"\bstrict\s+(private|protected)\b", "strict private/protected"),
    (r"\breference\s+to\b", "anonymous method type (reference to)"),
    (r"(:=|\(|,)\s*(procedure|function)\b", "anonymous method"),
    (r"\b(class|record|type)\s+helper\b", "class/record helper"),
    (r"\bclass\s+operator\b", "operator overloading"),
    (r"^\s*operator\b", "operator overloading"),
    (r"\binline\b", "inline"),
    (r"\bclass\s+var\b", "class var"),
    (r"\bclass\s+(property|const|threadvar)\b", "class property/const"),
    (r"\bclass\s+(sealed|abstract)\b", "class sealed/abstract"),
    (r";\s*(static|final)\s*;", "static/final method directive"),
    (r"\bDefault\s*\(", "Default()"),
    (r"\bvar\s+\w+\s*(:\s*[\w.]+\s*)?:=", "inline variable declaration"),
    (r"\b(generic|specialize)\b", "generics"),
    (r"\b[A-Za-z_]\w*\s*<\s*[A-Za-z_][\w.]*(\s*,\s*[A-Za-z_][\w.]*)*\s*>", "generics"),
]


class Violation(object):
    def __init__(self, path, line, message):
        self.path = path
        self.line = line
        self.message = message

    def __str__(self):
        return "%s:%d: %s" % (self.path, self.line, self.message)


def strip_comments(text):
    """Return (code, directives).

    code has comments and string literals replaced by spaces (newlines kept,
    so line numbers stay valid). directives is a list of (line, text) for
    every compiler directive {$...}.
    """
    out = []
    directives = []
    i = 0
    n = len(text)
    line = 1

    def blank(s):
        return "".join(c if c == "\n" else " " for c in s)

    while i < n:
        c = text[i]
        if c == "\n":
            line += 1
            out.append(c)
            i += 1
        elif c == "'":
            j = i + 1
            while j < n:
                if text[j] == "'":
                    if j + 1 < n and text[j + 1] == "'":
                        j += 2
                        continue
                    break
                if text[j] == "\n":
                    break
                j += 1
            out.append("'" + " " * (j - i - 1) + "'")
            i = j + 1
        elif text.startswith("//", i):
            j = text.find("\n", i)
            if j < 0:
                j = n
            out.append(" " * (j - i))
            i = j
        elif c == "{":
            j = text.find("}", i)
            if j < 0:
                j = n - 1
            chunk = text[i:j + 1]
            if chunk.startswith("{$"):
                directives.append((line, chunk))
            line += chunk.count("\n")
            out.append(blank(chunk))
            i = j + 1
        elif text.startswith("(*", i):
            j = text.find("*)", i)
            if j < 0:
                j = n - 2
            chunk = text[i:j + 2]
            line += chunk.count("\n")
            out.append(blank(chunk))
            i = j + 2
        else:
            out.append(c)
            i += 1
    return "".join(out), directives


def check_directives(path, directives, violations):
    stack = []
    for line, d in directives:
        m = re.match(r"\{\$(\w+)", d)
        if not m:
            continue
        name = m.group(1).upper()
        if name == "REGION" or name == "ENDREGION":
            violations.append(Violation(path, line, "{$%s}" % name))
        elif name == "IF":
            stack.append(("IF", line))
        elif name in ("IFDEF", "IFNDEF", "IFOPT"):
            stack.append(("IFDEF", line))
        elif name == "ENDIF":
            if not stack:
                violations.append(Violation(path, line, "unbalanced {$ENDIF}"))
            elif stack.pop()[0] == "IF":
                violations.append(Violation(path, line, "{$IF} closed with {$ENDIF}; use {$IFEND}"))
        elif name == "IFEND":
            if not stack:
                violations.append(Violation(path, line, "unbalanced {$IFEND}"))
            elif stack.pop()[0] != "IF":
                violations.append(Violation(path, line, "{$IFDEF} closed with {$IFEND}; use {$ENDIF}"))
    for kind, line in stack:
        if not path.lower().endswith(".inc"):
            violations.append(Violation(path, line, "unclosed {$%s}" % kind))


def check_uses(path, code, violations):
    for m in re.finditer(r"\buses\b(.*?);", code, re.IGNORECASE | re.DOTALL):
        line = code.count("\n", 0, m.start()) + 1
        for item in m.group(1).split(","):
            name = item.strip().split()[0] if item.strip() else ""
            if not name:
                continue
            low = name.lower()
            if "." in name:
                violations.append(Violation(path, line, "qualified unit name: %s" % name))
            elif low in PROGRAM_UNITS and path.lower().endswith((".dpr", ".lpr")):
                continue
            elif low not in ALLOWED_UNITS and not low.startswith(OWN_UNIT_PREFIXES):
                violations.append(Violation(path, line, "unit not allowed: %s" % name))


def block_bodies(code, opener):
    """Yield (start, body) for declaration blocks starting with opener regex
    and ending at the matching 'end' (counting nested record/class/object)."""
    tokens = re.compile(r"\b(record|class|object|interface|end|case|try|begin|asm)\b|[A-Za-z_]\w*|.", re.IGNORECASE | re.DOTALL)
    for m in re.finditer(opener, code, re.IGNORECASE):
        depth = 1
        pos = m.end()
        tm = tokens.search(code, pos)
        while tm is not None and depth > 0:
            word = (tm.group(1) or "").lower()
            if word in ("record",):
                depth += 1
            elif word == "class":
                after = code[tm.end():tm.end() + 40]
                if re.match(r"\s*(\(|\b(private|protected|public|published)\b|[A-Za-z_]\w*\s*[:;(])", after) and not re.match(r"\s*(of|function|procedure|constructor|destructor|property|var|operator)\b", after):
                    depth += 1
            elif word == "end":
                depth -= 1
            pos = tm.end()
            if depth == 0:
                break
            tm = tokens.search(code, pos)
        yield m.start(), code[m.end():pos]


def check_blocks(path, code, violations):
    for start, body in block_bodies(code, r"=\s*(packed\s+)?record\b"):
        if re.search(r"\b(procedure|function|constructor|destructor|property|class)\b", body, re.IGNORECASE):
            line = code.count("\n", 0, start) + 1
            violations.append(Violation(path, line, "record with methods"))
    for start, body in block_bodies(code, r"=\s*class\b(?!\s*(of\b|;|\([\w\s,.]*\)\s*;))"):
        # a nested section starts a line ("type" alone, or "const X = ...");
        # "const" as a parameter modifier does not count
        # optionally preceded by a visibility keyword on the same line
        # ("public const X = ...", "private type")
        vis = r"(?:(?:strict\s+)?(?:public|private|protected|published)\s+)?"
        if re.search(r"^\s*" + vis + r"(type|const|var)\s*$|^\s*" + vis + r"(type|const)\s+\w+\s*=", body, re.IGNORECASE | re.MULTILINE):
            line = code.count("\n", 0, start) + 1
            violations.append(Violation(path, line, "nested type/const/var section in class"))
    # old-style objects are allowed only as value types without a VMT
    # (optional values): zeroed memory must be a valid "not set" state
    for start, body in block_bodies(code, r"=\s*(packed\s+)?object\b"):
        m = re.search(r"\b(constructor|destructor|virtual|dynamic|abstract|override)\b", body, re.IGNORECASE)
        if m:
            line = code.count("\n", 0, start) + 1
            violations.append(Violation(path, line, "object type with %s (no VMT allowed)" % m.group(1).lower()))


def check_file(path, violations):
    with open(path, "rb") as f:
        raw = f.read()
    for idx, b in enumerate(raw):
        if b > 127:
            line = raw.count(b"\n", 0, idx) + 1
            violations.append(Violation(path, line, "non-ASCII byte in source (use #$xx constants)"))
            break
    text = raw.decode("latin-1")
    raw_lines = text.split("\n")
    code, directives = strip_comments(text)
    code_lines = code.split("\n")

    check_directives(path, directives, violations)
    check_uses(path, code, violations)
    check_blocks(path, code, violations)

    ident_re = re.compile(r"\b(%s)\b" % "|".join(FORBIDDEN_IDENTIFIERS), re.IGNORECASE)
    pattern_res = [(re.compile(p, re.IGNORECASE), msg) for p, msg in FORBIDDEN_PATTERNS]
    for no, cl in enumerate(code_lines, 1):
        allowed = ALLOW_MARKER in raw_lines[no - 1]
        if not allowed:
            for m in ident_re.finditer(cl):
                violations.append(Violation(path, no, "forbidden identifier: %s" % m.group(1)))
        for rx, msg in pattern_res:
            if rx.search(cl):
                violations.append(Violation(path, no, msg))


API_MARKER = re.compile(r"\{ API: (stable|internal)\.")


def check_api(files, violations):
    """API markers of the library units and the uses of stable interfaces.
    The levels of all units in the folder of a checked unit are read, so a
    single file can be checked too."""
    checked = set(os.path.abspath(f) for f in files
                  if os.path.basename(os.path.dirname(os.path.abspath(f))) == "source"
                  and f.lower().endswith(".pas"))
    folders = set(os.path.dirname(f) for f in checked)
    units = {}
    for folder in folders:
        for fn in sorted(os.listdir(folder)):
            if not fn.lower().endswith(".pas"):
                continue
            path = os.path.join(folder, fn)
            with open(path, encoding="latin-1") as f:
                text = f.read()
            markers = list(API_MARKER.finditer(text))
            level = None
            if len(markers) == 1:
                end = text.find("}", markers[0].end())
                if end >= 0 and re.match(r"\s*unit\b", text[end + 1:], re.IGNORECASE):
                    level = markers[0].group(1)
            if level is None:
                if path in checked:
                    violations.append(Violation(path, 1, "needs exactly one API marker directly before the unit line "
                                                "({ API: stable. or { API: internal.)"))
                continue
            units[fn[:-4].lower()] = (path, level, text)
    for name, (path, level, text) in sorted(units.items()):
        if level != "stable" or path not in checked:
            continue
        code, _ = strip_comments(text)
        m = re.search(r"\binterface\b(.*?)\bimplementation\b", code, re.IGNORECASE | re.DOTALL)
        if not m:
            continue
        u = re.search(r"\buses\b(.*?);", m.group(1), re.IGNORECASE | re.DOTALL)
        if not u:
            continue
        for item in u.group(1).split(","):
            used = item.strip().split()[0].lower() if item.strip() else ""
            if used in units and units[used][1] != "stable":
                line = code.count("\n", 0, m.start(1) + u.start()) + 1
                violations.append(Violation(path, line, "stable unit uses internal unit %s in its interface" %
                                            item.strip().split()[0]))


def main(argv):
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    paths = argv[1:] or [os.path.join(root, d) for d in ("source", "tests", "examples")]
    files = []
    for p in paths:
        if os.path.isfile(p):
            files.append(p)
        elif os.path.isdir(p):
            for dirpath, dirnames, filenames in os.walk(p):
                dirnames[:] = [d for d in dirnames if d not in ("local", "build", "data")]
                for fn in sorted(filenames):
                    if fn.lower().endswith(EXTENSIONS):
                        files.append(os.path.join(dirpath, fn))
    violations = []
    for f in files:
        check_file(f, violations)
    check_api(files, violations)
    for v in violations:
        print(v)
    print("check-forbidden: %d file(s), %d violation(s)" % (len(files), len(violations)))
    return 1 if violations else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
