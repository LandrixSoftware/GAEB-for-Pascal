#!/usr/bin/env python3
"""Checks tools/legacy/da2000-blocks.json, the table of GAEB DA 2000 objects
and elements, and compares it with a folder of GAEB DA 2000 files.

  python tools/legacy/da2000-blocks.py --check
      consistency of the table: object references, data types, lengths,
      versions, structures, duplicate keywords (case-insensitive).

  python tools/legacy/da2000-blocks.py --corpus <folder>
      reads every GAEB DA 2000 file below <folder> (first line #begin[GAEB])
      with a minimal tokenizer and counts, per object, keywords the table
      does not know, objects used as elements and the reverse, opaque
      objects and vendor keywords (leading _). Prints keywords and counts
      only, never values: the files may hold customer data.

Exit code 0 = the table is consistent (and, with --corpus, the folder was
read); differences against the corpus are findings, not errors.
"""
import argparse
import collections
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
TABLE = os.path.join(HERE, "da2000-blocks.json")
TYPES = {"alphanum", "num", "date", "time", "week", "oz", "stlnr", "text", "lvtext", "struct", "object"}


def no_duplicates(pairs):
    """object_pairs_hook: json.load would keep the last of two equal keys."""
    seen = {}
    for k, v in pairs:
        if k in seen:
            raise ValueError("key %s twice in one JSON object" % k)
        seen[k] = v
    return seen


def load():
    with open(TABLE, encoding="utf-8") as f:
        return json.load(f, object_pairs_hook=no_duplicates)


def is_int(x):
    return isinstance(x, int) and not isinstance(x, bool)


def check_len(where, entry, problems):
    t = entry.get("type")
    n = entry.get("len")
    if t == "alphanum":
        if not is_int(n) or n <= 0:
            problems.append("%s: alphanum needs a positive len" % where)
    elif t == "num":
        if not (isinstance(n, list) and len(n) == 2 and all(is_int(x) for x in n)
                and n[0] > 0 and 0 <= n[1] < n[0]):
            problems.append("%s: num needs len [total, fraction]" % where)
    elif "len" in entry:
        problems.append("%s: type %s takes no len" % (where, t))


def check_versions(where, entry, versions, problems):
    """since/until known and in order; names keyed by known versions."""
    for v in ("since", "until"):
        if v in entry and entry[v] not in versions:
            problems.append("%s: unknown version %s" % (where, entry[v]))
    if (entry.get("since") in versions and entry.get("until") in versions
            and versions.index(entry["since"]) > versions.index(entry["until"])):
        problems.append("%s: since after until" % where)
    for v in entry.get("names", {}):
        if v not in versions:
            problems.append("%s: unknown version %s in names" % (where, v))


def check_components(where, comps, table, problems, allow_ref=True):
    """A list of components, or (in an element) the name of a shared one."""
    if isinstance(comps, str) and allow_ref:
        if not isinstance(table["structures"].get(comps), list):
            problems.append("%s: unknown structure %s" % (where, comps))
        return
    if not isinstance(comps, list) or not comps:
        problems.append("%s: components missing" % where)
        return
    for c in comps:
        cw = "%s|%s" % (where, c.get("name"))
        if c.get("type") not in TYPES - {"struct", "object"}:
            problems.append("%s: bad component type %s" % (cw, c.get("type")))
        check_len(cw, c, problems)


def check(table):
    problems = []
    versions = table["versions"]
    objects = table["objects"]
    lower = collections.Counter(k.lower() for k in objects)
    for k, n in lower.items():
        if n > 1:
            problems.append("object %s defined twice" % k)
    for name, obj in objects.items():
        check_versions(name, obj, versions, problems)
        if obj.get("opaque"):
            if "children" in obj or "elementForm" in obj:
                problems.append("%s: opaque objects have no children and no element form" % name)
            continue
        if "elementForm" in obj:
            form = obj["elementForm"]
            check_versions(name + " (element form)", form, versions, problems)
            check_components(name + " (element form)", form.get("components"), table, problems)
        seen = set()
        for e in obj.get("children", []):
            key = e.get("key", "")
            where = "%s/%s" % (name, key)
            if not re.match(r"^[A-Za-z][A-Za-z0-9_]*$", key):
                problems.append("%s: bad keyword" % where)
            for alias in [key] + list(e.get("names", {}).values()):
                if alias.lower() in seen:
                    problems.append("%s: keyword %s twice" % (where, alias))
                seen.add(alias.lower())
            t = e.get("type")
            if t not in TYPES:
                problems.append("%s: unknown type %s" % (where, t))
                continue
            check_versions(where, e, versions, problems)
            if t == "object":
                if key not in objects:
                    problems.append("%s: object not defined" % where)
                if "len" in e or "components" in e:
                    problems.append("%s: an object has no len or components" % where)
            elif t == "struct":
                if "len" in e:
                    problems.append("%s: a structure has no len" % where)
                check_components(where, e.get("components"), table, problems)
            else:
                if "components" in e:
                    problems.append("%s: only a structure has components" % where)
                check_len(where, e, problems)
            if "values" in e and not (isinstance(e["values"], list)
                                      and all(isinstance(x, str) for x in e["values"])):
                problems.append("%s: values must be strings" % where)
    # every object is reachable from GAEB
    reached = set()
    todo = ["GAEB"]
    while todo:
        name = todo.pop()
        if name in reached or name not in objects:
            continue
        reached.add(name)
        for e in objects[name].get("children", []):
            if e.get("type") == "object":
                todo.append(e.get("key"))
    for name in objects:
        if name not in reached:
            problems.append("object %s is not reachable from GAEB" % name)
    for dp, ph in table["phases"].items():
        if ph["main"] not in objects:
            problems.append("phase %s: unknown main object %s" % (dp, ph["main"]))
    for name, comps in table["structures"].items():
        check_components("structure " + name, comps, table, problems, allow_ref=False)
    return problems


# ---- corpus ----

BEGIN = re.compile(rb"^\s*#begin\[([^\]]*)\]", re.I)
END = re.compile(rb"^\s*#end\[([^\]]*)\]", re.I)
ELEMENT = re.compile(rb"^\s*\[([^\]]*)\]", re.I)
END_MARK = re.compile(rb"\[end\]\s*$", re.I)


KEYWORD = re.compile(r"^[A-Za-z_][A-Za-z0-9_]{0,63}$")


def tokens(data):
    """(kind, keyword, first line of the value) for begin/end/element."""
    lines = data.split(b"\n")
    i = 0
    while i < len(lines):
        line = lines[i].rstrip(b"\r")
        i += 1
        if line.strip().startswith(b"##") or not line.strip():
            continue
        m = BEGIN.match(line)
        if m:
            yield "begin", m.group(1).decode("latin-1"), b""
            continue
        m = END.match(line)
        if m:
            yield "end", m.group(1).decode("latin-1"), b""
            continue
        m = ELEMENT.match(line)
        if m:
            yield "element", m.group(1).decode("latin-1"), END_MARK.sub(b"", line[m.end():])
            # a value runs to the line that ends with [end]
            while not END_MARK.search(line) and i < len(lines):
                line = lines[i].rstrip(b"\r")
                i += 1
            continue
        yield "stray", "", b""


def shown(key):
    """A keyword for the output; anything that is not a keyword is not printed."""
    key = key.strip()
    return key if KEYWORD.match(key) else "<not a keyword>"


def corpus(table, folder):
    objects = {k.lower(): (k, v) for k, v in table["objects"].items()}
    keys = {}
    for name, obj in table["objects"].items():
        m = {}
        for e in obj.get("children", []):
            for alias in [e["key"]] + list(e.get("names", {}).values()):
                m[alias.lower()] = e
        keys[name] = m
    files = 0
    versions = collections.Counter()
    unknown = collections.Counter()
    vendor = collections.Counter()
    opaque = collections.Counter()
    shape = collections.Counter()
    unbalanced = 0
    stray = 0
    for root, _dirs, names in os.walk(folder):
        for n in sorted(names):
            path = os.path.join(root, n)
            with open(path, "rb") as f:
                data = f.read()
            if not data.lstrip()[:12].lower().startswith(b"#begin[gaeb]"):
                continue
            files += 1
            version = "none"
            balanced = True
            # (opened keyword in lower case, table object or None when its
            # content is not inspected: opaque, unknown or vendor objects)
            stack = []
            for kind, key, value in tokens(data):
                low = key.strip().lower()
                if kind == "stray":
                    stray += 1
                    continue
                if kind == "end":
                    if stack and stack[-1][0] == low:
                        stack.pop()
                    else:
                        balanced = False
                    continue
                inspect = not stack or stack[-1][1] is not None
                parent = stack[-1][1] if stack else None
                if not inspect:
                    if kind == "begin":
                        stack.append((low, None))
                    continue
                if low.startswith("_"):
                    vendor["%s/%s" % (parent, shown(key))] += 1
                    if kind == "begin":
                        stack.append((low, None))
                    continue
                entry = keys.get(parent, {}).get(low) if parent else None
                if kind == "begin":
                    target = objects.get(low)
                    if parent is not None and entry is None:
                        unknown["%s/#%s" % (parent, shown(key))] += 1
                    elif entry is not None and entry["type"] != "object":
                        shape["%s/%s used as object" % (parent, entry["key"])] += 1
                    if target is None:
                        stack.append((low, None))
                    elif target[1].get("opaque"):
                        opaque[target[0]] += 1
                        stack.append((low, None))
                    else:
                        stack.append((low, target[0]))
                else:
                    if parent == "GAEBInfo" and low == "version":
                        # only a known label is printed
                        text = value.strip().decode("latin-1")
                        version = text if text in table["versions"] else "other"
                    if entry is None:
                        unknown["%s/%s" % (parent, shown(key))] += 1
                    elif entry["type"] == "object":
                        form = "element form" if "elementForm" in table["objects"][entry["key"]] else "element"
                        shape["%s/%s used as %s" % (parent, entry["key"], form)] += 1
            versions[version] += 1
            if stack or not balanced:
                unbalanced += 1
    print("da2000-blocks: %d file(s); versions %s" % (files, dict(sorted(versions.items()))))
    print("  file(s) with unbalanced #begin/#end: %d, lines outside any element: %d" % (unbalanced, stray))
    for title, counter in (("unknown keywords", unknown), ("objects/elements swapped", shape),
                           ("opaque objects", opaque), ("vendor keywords", vendor)):
        print("  %s: %d distinct, %d use(s)" % (title, len(counter), sum(counter.values())))
        for k, v in sorted(counter.items(), key=lambda kv: (-kv[1], kv[0])):
            print("    %6d  %s" % (v, k))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--corpus")
    args = ap.parse_args()
    table = load()
    problems = check(table)
    for p in problems:
        print("PROBLEM " + p)
    if args.check or not args.corpus:
        print("da2000-blocks: %d object(s), %d element(s), %d problem(s)" % (
            len(table["objects"]),
            sum(len(o.get("children", [])) for o in table["objects"].values()), len(problems)))
    if args.corpus:
        corpus(table, args.corpus)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
