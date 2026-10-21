#!/usr/bin/env python3
"""Checks GAEB DA XML files against the context descriptions written by
extract-gaeb-xsd.py (tools/schema/out/<id>.json). A development tool for
verifying the extraction, not a schema validator: it checks namespace,
element names, order and cardinality against the particle trees, required
and unknown attributes, and enumerations, patterns, lengths and digits of
simple values. ID/IDREF and identity constraints are not checked.

The context is chosen from namespace and VersDate. Messages name the file
and an element path, never content of the file.

Usage:
  python tools/schema/check-instance.py FILE_OR_FOLDER...
"""

import io
import json
import os
import re
import sys
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")


def load_contexts():
    result = {}
    if not os.path.isdir(OUT):
        sys.stderr.write("check-instance: run extract-gaeb-xsd.py first\n")
        sys.exit(2)
    for name in sorted(os.listdir(OUT)):
        if name.endswith(".json"):
            d = json.load(io.open(os.path.join(OUT, name), encoding="utf-8"))
            if "context" not in d:
                continue  # gaeb-merged.json
            result[(d["namespace"], d["context"]["edition"])] = d
    return result


class Checker(object):
    def __init__(self, ctx):
        self.ctx = ctx
        self.types = ctx["types"]
        self.ns = "{" + ctx["namespace"] + "}"
        self.errors = []
        self.memo = {}

    def error(self, path, msg):
        if len(self.errors) < 50:
            self.errors.append("%s: %s" % (path, msg))

    # ---- particles: set of end positions, with backtracking ----

    def match(self, p, names, pos):
        key = (id(p), pos)
        if key in self.memo:
            return self.memo[key]
        ends = set()
        current = {pos}
        seen = {pos}
        count = 0
        if p["min"] == 0:
            ends.add(pos)
        while current and (p["max"] == -1 or count < p["max"]):
            nxt = set()
            for q in current:
                nxt |= self.match_once(p, names, q)
            count += 1
            if count >= p["min"]:
                ends |= nxt
                # further rounds only matter for positions not reached yet
                nxt -= seen
                seen |= nxt
            if count > len(names) + p["min"] + 1:
                break
            current = nxt
        self.memo[key] = ends
        return ends

    def match_once(self, p, names, pos):
        if p["k"] == "element":
            return {pos + 1} if pos < len(names) and names[pos] == p["name"] else set()
        if p["k"] == "choice":
            ends = set()
            for item in p["items"]:
                ends |= self.match(item, names, pos)
            return ends
        current = {pos}
        for item in p["items"]:
            nxt = set()
            for q in current:
                nxt |= self.match(item, names, q)
            current = nxt
            if not current:
                break
        return current

    def element_types(self, p, result):
        if p["k"] == "element":
            if p["name"] in result and result[p["name"]] != p["type"]:
                result[p["name"]] = None  # same name, different types: not supported here
            else:
                result.setdefault(p["name"], p["type"])
        else:
            for item in p["items"]:
                self.element_types(item, result)
        return result

    # ---- values ----

    def check_simple(self, tname, value, path):
        if tname.startswith("xs:"):
            return self.check_builtin(tname, value, path)
        t = self.types[tname]
        if t["kind"] == "union":
            saved = self.errors
            for m in t["members"]:
                self.errors = []
                self.check_simple(m, value, path)
                if not self.errors:
                    self.errors = saved
                    return
            self.errors = saved
            self.error(path, "value matches no member of %s" % tname)
            return
        if t["kind"] == "complex":
            return self.check_simple(t["simple"], value, path)
        base = t["base"]
        v = value
        if base in ("xs:normalizedString", "xs:token") or base not in ("xs:string",):
            v = " ".join(value.split()) if base != "xs:normalizedString" else value.replace("\t", " ").replace("\n", " ").replace("\r", " ")
        if base not in ("xs:string", "xs:normalizedString"):
            v = " ".join(value.split())
        self.check_builtin(base, v, path)
        f = t["facets"]
        if "enumeration" in t and v not in t["enumeration"]:
            self.error(path, "value not in the enumeration of %s" % tname)
        for step in t.get("patterns", []):
            if not any(re.fullmatch(xsd_regex(pat), v) for pat in step):
                self.error(path, "value does not match the pattern of %s" % tname)
        if "maxLength" in f and len(v) > int(f["maxLength"]):
            self.error(path, "value longer than %s (%s)" % (f["maxLength"], tname))
        if "minLength" in f and len(v) < int(f["minLength"]):
            self.error(path, "value shorter than %s (%s)" % (f["minLength"], tname))
        if base == "xs:decimal" and re.fullmatch(r"[+-]?(\d+(\.\d*)?|\.\d+)", v):
            ip, _, fp = v.lstrip("+-").partition(".")
            fp = fp.rstrip("0")
            ip = ip.lstrip("0")
            if "fractionDigits" in f and len(fp) > int(f["fractionDigits"]):
                self.error(path, "more than %s fraction digits (%s)" % (f["fractionDigits"], tname))
            if "totalDigits" in f and len(ip) + len(fp) > int(f["totalDigits"]):
                self.error(path, "more than %s digits (%s)" % (f["totalDigits"], tname))

    def check_builtin(self, base, v, path):
        patterns = {
            "xs:decimal": r"[+-]?(\d+(\.\d*)?|\.\d+)",
            "xs:integer": r"[+-]?\d+",
            "xs:nonNegativeInteger": r"\+?\d+",
            "xs:positiveInteger": r"\+?0*[1-9]\d*",
            "xs:date": r"-?\d{4,}-\d\d-\d\d(Z|[+-]\d\d:\d\d)?",
            "xs:time": r"\d\d:\d\d:\d\d(\.\d+)?(Z|[+-]\d\d:\d\d)?",
            "xs:gYearMonth": r"-?\d{4,}-\d\d(Z|[+-]\d\d:\d\d)?",
            "xs:ID": r"[A-Za-z_][\w.\-]*",
            "xs:IDREF": r"[A-Za-z_][\w.\-]*",
            "xs:NCName": r"[A-Za-z_][\w.\-]*",
        }
        if base in patterns and not re.fullmatch(patterns[base], v.strip()):
            self.error(path, "not a valid %s" % base)

    # ---- elements ----

    def check_element(self, el, tname, path):
        t = self.types.get(tname) if not tname.startswith("xs:") else None
        attrs = t["attributes"] if t and t["kind"] == "complex" else []
        known = dict((a["name"], a) for a in attrs)
        for a in el.attrib:
            if a.startswith("{"):
                continue  # xsi:, xml:
            if a not in known:
                self.error(path, "unknown attribute %s" % a)
            else:
                self.check_simple(known[a]["type"], el.attrib[a], path + "/@" + a)
        for a in attrs:
            if a["use"] == "required" and a["name"] not in el.attrib:
                self.error(path, "missing attribute %s" % a["name"])
        kids = [c for c in el if isinstance(c.tag, str)]
        if t is None or t["kind"] != "complex" or "simple" in t:
            if kids:
                self.error(path, "element content in a simple type")
                return
            self.check_simple(tname, el.text or "", path)
            return
        if (el.text or "").strip() and not t.get("mixed"):
            self.error(path, "text in element-only content")
        for c in kids:
            if (c.tail or "").strip() and not t.get("mixed"):
                self.error(path, "text in element-only content")
                break
        names = []
        for c in kids:
            if not c.tag.startswith(self.ns):
                self.error(path, "element of another namespace %s" % c.tag.split("}")[0][1:])
                names.append(None)
            else:
                names.append(c.tag[len(self.ns):])
        p = t["particle"]
        self.memo = {}
        if p is None:
            if kids:
                self.error(path, "element content in an empty type")
        elif len(names) not in self.match(p, names, 0):
            self.error(path, "children do not match the content model: " + " ".join(n or "?" for n in names[:40]))
        child_types = self.element_types(p, {}) if p else {}
        counter = {}
        for c, n in zip(kids, names):
            if n is None or n not in child_types:
                continue
            counter[n] = counter.get(n, 0) + 1
            if child_types[n] is None:
                self.error(path, "child %s has different types in the content model; not descended" % n)
                continue
            self.check_element(c, child_types[n], "%s/%s[%d]" % (path, n, counter[n]))


def xsd_regex(pattern):
    # XSD regular expressions are implicitly anchored; \i and \c are not used by GAEB
    return pattern


def check_file(contexts, path):
    try:
        root = ET.parse(path).getroot()
    except ET.ParseError as e:
        return "not well-formed (%s)" % e.position.__repr__(), None
    if not root.tag.startswith("{"):
        return "no namespace", None
    ns = root.tag[1:].split("}")[0]
    vd = root.find("{%s}GAEBInfo/{%s}VersDate" % (ns, ns))
    edition = (vd.text or "").strip() if vd is not None else ""
    ctx = contexts.get((ns, edition))
    if ctx is None:
        return "no context for %s %s" % (ns, edition), None
    c = Checker(ctx)
    if root.tag != "{%s}%s" % (ns, ctx["root"]["name"]):
        return "wrong root", ctx
    c.check_element(root, ctx["root"]["type"], "/" + ctx["root"]["name"])
    return c.errors, ctx


def main(argv):
    if len(argv) < 2:
        sys.stderr.write(__doc__)
        return 2
    contexts = load_contexts()
    files = []
    for a in argv[1:]:
        if os.path.isdir(a):
            for dirpath, _, names in os.walk(a):
                files.extend(os.path.join(dirpath, n) for n in sorted(names))
        else:
            files.append(a)
    status = 0
    for f in files:
        result, ctx = check_file(contexts, f)
        name = os.path.basename(f)
        if isinstance(result, str):
            print("%s: skipped, %s" % (name, result))
            continue
        cid = ctx["context"]["id"]
        if result:
            status = 1
            print("%s [%s]: %d problem(s)" % (name, cid, len(result)))
            for e in result:
                print("  " + e)
        else:
            print("%s [%s]: ok" % (name, cid))
    return status


if __name__ == "__main__":
    sys.exit(main(sys.argv))
