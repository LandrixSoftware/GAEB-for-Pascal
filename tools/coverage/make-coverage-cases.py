#!/usr/bin/env python3
"""Writes synthetic GAEB DA XML documents that cover the model of every
target (plan, phase 1 step 9), derived from the context descriptions of
extract-gaeb-xsd.py (tools/schema/out/<context>.json):

  tests/data/coverage/<context>-minimal.x8n   only what the schema requires
  tests/data/coverage/<context>-full-<k>.x8n  every optional element and
                                              attribute; document k starts
                                              every choice at alternative k
                                              (each further visit takes the
                                              next one), a repeated choice
                                              gives every alternative once,
                                              enumerations start at code k

Together the full documents hold every element and attribute of every
context except QtySplit/QtyPcnt, whose choice is always reached together
with the same alternative of the enclosing one (covered by the rule case
GAEB-BR-QTY-002/valid-2). "--report" prints the coverage.

Values keep the facets (lengths, digits, ranges, patterns); decimals are
written with the fraction digits of their type, as the writer does. All
content is invented. The documents are checked against the XSDs by
tests/LandrixGaebTestXsd.pas and read and written by
tests/LandrixGaebTestCoverage.pas.

Usage:
  python tools/coverage/make-coverage-cases.py           write the documents
  python tools/coverage/make-coverage-cases.py --check   exit 1 if a file differs
  python tools/coverage/make-coverage-cases.py --report  coverage per context
"""

import io
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
SCHEMA_OUT = os.path.join(ROOT, "tools", "schema", "out")
OUT = os.path.join(ROOT, "tests", "data", "coverage")

CONTEXTS = ["%s-%s" % (e, p) for e in ("3.2-2013-10", "3.3-2019-11", "3.3-2021-05")
            for p in ("81", "83", "84", "86")]

# deepest nesting of elements; below it only required content
MAX_DEPTH = 24
# a complex type may be nested in itself this often (text types would
# grow too fast); the structure of the bill of quantities twice, so that a
# category holds items
MAX_NESTING = 1
NESTING = {"tgBoQBody": 2, "tgBoQCtgy": 2}
# repeated particles are written twice down to this depth, else once
REPEAT_DEPTH = 0
# full documents per context: document k starts every choice at
# alternative k (each visit then takes the next one)
FULL_DOCUMENTS = 2
# repeated choices give every alternative once down to this depth
CHOICE_DEPTH = 12

# values of simple types with a pattern
PATTERN_VALUES = {
    "tgRNoPart": "1",
    "tgRNoIndex": "A",
    "tgIBAN": "DE00TEST0000",
    "tgQTakeoffRow": " " * 11 + "X" * 69,
    "tgStLNoText": "123",
}


class Generator(object):
    def __init__(self, ctx, full, variant):
        self.ctx = ctx
        self.types = ctx["types"]
        self.full = full
        self.variant = variant
        self.next_id = 0
        self.ids = []
        self.stack = []
        self.used = set()
        self.visits = {}

    # ---- simple values ----

    def simple(self, name):
        if name.startswith("xs:"):
            return {"kind": "simple", "base": name, "facets": {}}
        t = self.types[name]
        return t

    def value(self, type_name, k=0):
        if type_name in PATTERN_VALUES:
            return PATTERN_VALUES[type_name]
        t = self.simple(type_name)
        if t["kind"] == "union":
            return self.value(t["members"][0], k)
        if t.get("enumeration"):
            enum = t["enumeration"]
            return enum[(self.variant + k) % len(enum)]
        base = t["base"]
        facets = dict(t.get("facets", {}))
        if not base.startswith("xs:"):
            # restriction of another named type: its facets apply too
            inner = self.simple(base)
            if inner.get("enumeration"):
                return inner["enumeration"][(self.variant + k) % len(inner["enumeration"])]
            merged = dict(inner.get("facets", {}))
            merged.update(facets)
            facets = merged
            base = inner["base"]
        if base == "xs:decimal":
            fd = int(facets.get("fractionDigits", "0"))
            s = "1" + ("." + "1" * fd if fd else "")
            if "minInclusive" in facets and float(s) < float(facets["minInclusive"]):
                s = facets["minInclusive"]
            return s
        if base in ("xs:integer", "xs:nonNegativeInteger", "xs:positiveInteger"):
            v = 1
            if "minInclusive" in facets:
                v = max(v, int(facets["minInclusive"]))
            if "maxInclusive" in facets:
                v = min(v, int(facets["maxInclusive"]))
            return str(v)
        if base == "xs:date":
            return "2026-01-15"
        if base == "xs:time":
            return "12:30:00"
        if base == "xs:gYearMonth":
            return "2026-01"
        s = "Wert%d" % (self.variant + 1)
        if "maxLength" in facets:
            s = s[:int(facets["maxLength"])]
        return s

    # ---- attributes ----

    def attributes(self, t):
        out = []
        for a in t.get("attributes", []):
            required = a.get("use") == "required"
            if not required and not self.full:
                continue
            ty = a["type"]
            if ty == "xs:ID":
                self.next_id += 1
                v = "X%d" % self.next_id
                self.ids.append(v)
            elif ty == "xs:IDREF":
                v = "X1"
            elif a["name"] == "ID" and ty == "tgGUID32":
                # unique per document (identity constraint of descriptions)
                self.next_id += 1
                v = "G%d" % self.next_id
            else:
                v = self.value(ty)
            out.append(' %s="%s"' % (a["name"], v))
            self.used.add((self.current, "@" + a["name"]))
        return "".join(out)

    # ---- elements ----

    def special(self, name):
        c = self.ctx["context"]
        if name == "Version":
            return c["version"]
        if name == "VersDate":
            return c["edition"]
        if name == "DP":
            return c["phase"]
        return None

    def element(self, name, type_name, depth):
        if self.stack:
            self.used.add((self.stack[-1], name))
        sp = self.special(name)
        if sp is not None:
            return "<%s>%s</%s>" % (name, sp, name)
        t = self.types.get(type_name) if not type_name.startswith("xs:") else None
        if t is None or t["kind"] != "complex":
            return "<%s>%s</%s>" % (name, self.value(type_name), name)
        self.current = type_name
        attrs = self.attributes(t)
        if "simple" in t:
            return "<%s%s>%s</%s>" % (name, attrs, self.value(t["simple"]), name)
        if not t.get("particle"):
            return "<%s%s/>" % (name, attrs)
        recursive = self.stack.count(type_name) >= NESTING.get(type_name, MAX_NESTING) or depth >= MAX_DEPTH
        self.stack.append(type_name)
        try:
            body = self.particle(t["particle"], depth + 1, not recursive and self.full)
        finally:
            self.stack.pop()
        if body == "":
            return "<%s%s/>" % (name, attrs)
        return "<%s%s>%s</%s>" % (name, attrs, body, name)

    def particle(self, p, depth, full):
        if p["min"] == 0 and not full:
            return ""
        count = max(p["min"], 1)
        if full and p["max"] != 1:
            if p["k"] == "choice" and depth <= CHOICE_DEPTH and p["items"]:
                # a repeated choice: every alternative once
                count = max(count, len(p["items"]))
            elif depth <= REPEAT_DEPTH:
                count = max(count, 2)
        out = []
        for i in range(count):
            out.append(self.one(p, depth, full, i))
        return "".join(out)

    def one(self, p, depth, full, i):
        k = p["k"]
        if k == "element":
            return self.element(p["name"], p["type"], depth)
        if k == "sequence":
            return "".join(self.particle(q, depth, full) for q in p["items"])
        if k == "choice":
            items = p["items"]
            if not items:
                # emptied by a restriction of the phase schema
                return ""
            if full:
                # every visit of the same choice takes the next alternative
                n = self.visits.get(id(p), 0)
                self.visits[id(p)] = n + 1
                q = items[(self.variant + n) % len(items)]
            else:
                q = self.lightest(items)
            return self.particle(dict(q, min=max(q["min"], 1)), depth, full)
        raise ValueError(k)

    def lightest(self, items):
        """The alternative with the least required content (for minimal
        documents)."""
        best, best_size = items[0], None
        for q in items:
            size = len(self.size_probe(q))
            if best_size is None or size < best_size:
                best, best_size = q, size
        return best

    def size_probe(self, q):
        saved = (self.next_id, list(self.ids))
        try:
            return self.particle(dict(q, min=max(q["min"], 1)), MAX_DEPTH, False)
        finally:
            self.next_id, self.ids = saved

    def document(self):
        root = self.ctx["root"]
        body = self.element(root["name"], root["type"], 0)
        ns = self.ctx["namespace"]
        body = body.replace("<%s" % root["name"], '<%s xmlns="%s"' % (root["name"], ns), 1)
        return '<?xml version="1.0" encoding="UTF-8"?>\n' + body + "\n"


def max_choice(ctx):
    widest = 1
    for t in ctx["types"].values():
        stack = [t.get("particle")] if t.get("particle") else []
        while stack:
            p = stack.pop()
            if p["k"] == "choice":
                widest = max(widest, len(p["items"]))
            if p["k"] != "element":
                stack.extend(p["items"])
        if t.get("enumeration"):
            widest = max(widest, len(t["enumeration"]))
    return widest


def declared(ctx):
    """(type, element) and (type, @attribute) pairs of a context."""
    names = set()
    for tn, t in ctx["types"].items():
        for a in t.get("attributes", []):
            names.add((tn, "@" + a["name"]))
        stack = [t.get("particle")] if t.get("particle") else []
        while stack:
            p = stack.pop()
            if p["k"] == "element":
                names.add((tn, p["name"]))
            else:
                stack.extend(p["items"])
    return names


def files(report=None):
    result = {}
    for cid in CONTEXTS:
        ctx = json.load(io.open(os.path.join(SCHEMA_OUT, cid + ".json"), encoding="utf-8"))
        ext = ".x" + ctx["context"]["phase"]
        result[cid + "-minimal" + ext] = Generator(ctx, False, 0).document()
        seen = set()
        for k in range(FULL_DOCUMENTS):
            g = Generator(ctx, True, k)
            result["%s-full-%02d%s" % (cid, k + 1, ext)] = g.document()
            seen |= g.used
        if report is not None:
            want = declared(ctx)
            report.append((cid, len(want & seen), len(want), sorted(want - seen)))
    return result


def main(argv):
    check = "--check" in argv[1:]
    status = 0
    all_files = files()
    for name, content in sorted(all_files.items()):
        path = os.path.join(OUT, name)
        data = content.encode("utf-8")
        if check:
            if not os.path.exists(path) or io.open(path, "rb").read() != data:
                sys.stderr.write("make-coverage-cases: %s is not up to date\n" % name)
                status = 1
            continue
        if not os.path.isdir(OUT):
            os.makedirs(OUT)
        io.open(path, "wb").write(data)
    if "--report" in argv[1:]:
        report = []
        files(report)
        for cid, got, want, missing in report:
            print("%s: %d of %d elements and attributes" % (cid, got, want))
            for m in missing:
                print("  missing %s/%s" % m)
        if not check:
            return 0
    if not check:
        size = sum(len(c.encode("utf-8")) for c in all_files.values())
        print("make-coverage-cases: %d file(s), %d bytes in tests/data/coverage" % (len(all_files), size))
    elif status == 0:
        print("make-coverage-cases: documents up to date")
    return status


if __name__ == "__main__":
    sys.exit(main(sys.argv))
