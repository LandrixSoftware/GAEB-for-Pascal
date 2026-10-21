#!/usr/bin/env python3
"""Merges the context descriptions of extract-gaeb-xsd.py
(tools/schema/out/<id>.json) into one class list for the common object
surface (tools/schema/out/gaeb-merged.json, git-ignored). The checksum of
the result is kept in merged.sha256 (committed).

Shape of a complex type (per context, from its particle tree):
  - fields: elements outside repeated regions (name, type, maxOccurs as the
    product along the path);
  - children: the elements of a repeated particle with more than one
    element name and no mandatory member (repeated choice, interleaved
    sequence such as (th*, td*)+). They are kept as one ordered list.
  - group: a repeated sequence with more than one element name and at least
    one mandatory member (an anchor), e.g. (CnstSite, NotifSite?)*. It
    becomes a class of its own ("<type>/group") in a list field.
At most one children region and one group per type; anything else stops.

One class per type name, if the shapes of all contexts are compatible:
  - same kind (element content, simple content, simple; unions count as
    simple text);
  - an element name is a field in every context or a child in every context;
  - same type name for complex types (or a "widen" decision), the same value
    family for simple types (bounded decimal, unbounded decimal, integer,
    text, date, time, gYearMonth, float, boolean, base64);
  - the field order of all contexts fits into one order.
An element that is an ordered child in one context is one in all contexts.
Cardinality and presence may differ. Fields, children, attributes and
enumeration values carry "published": False when they exist only in
contexts with publish = false (3.4 beta); "list" and "use" are computed from
the published contexts where the member exists in any. The field list holds
the placeholders "#children" and "#group" at the position of the ordered
region and of the group. Simple types carry their value family, the union
of their enumeration values (also through unions) and "open" when a
published context accepts values outside the enumeration; facets and
patterns stay in the per-context files. The per-context particle trees stay
authoritative for writing and checking.

merge-exceptions.json (committed) holds decisions per type: "widen" maps
child elements to a wider type whose children contain those of every
narrower type (names, types, cardinality; checked here). Any other decision
and widen entries for unknown elements stop the merge, as do unresolved
conflicts.

Usage:
  python tools/schema/merge-gaeb.py           merge, report conflicts
  python tools/schema/merge-gaeb.py --check   exit 1 if merged.sha256 differs
"""

import hashlib
import io
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out")
HASHES = os.path.join(HERE, "merged.sha256")
EXCEPTIONS = os.path.join(HERE, "merge-exceptions.json")

FAMILY = {
    "xs:decimal": "decimal", "xs:integer": "integer", "xs:nonNegativeInteger": "integer",
    "xs:positiveInteger": "integer", "xs:string": "text", "xs:normalizedString": "text",
    "xs:token": "text", "xs:ID": "text", "xs:IDREF": "text", "xs:NCName": "text",
    "xs:date": "date", "xs:time": "time", "xs:gYearMonth": "gYearMonth", "xs:float": "float",
    "xs:boolean": "boolean", "xs:base64Binary": "base64",
}


def fail(msg):
    sys.stderr.write("merge-gaeb: " + msg + "\n")
    sys.exit(2)


def load_contexts():
    manifest = json.load(io.open(os.path.join(HERE, "manifest.json"), encoding="utf-8"))
    result = []
    for ctx in manifest["contexts"]:
        path = os.path.join(OUT, ctx["id"] + ".json")
        if not os.path.exists(path):
            fail("%s missing, run extract-gaeb-xsd.py first" % path)
        result.append(json.load(io.open(path, encoding="utf-8")))
    return result


def mul(a, b):
    return -1 if a == -1 or b == -1 else a * b


def add(a, b):
    return -1 if a == -1 or b == -1 else a + b


def kind_of(t):
    if t["kind"] == "complex":
        return "simplecontent" if "simple" in t else "complex"
    return "simple"


def family(types, name):
    """Value family of a simple type (or of the simple content of a type)."""
    if name.startswith("xs:"):
        return FAMILY[name]
    t = types[name]
    if t["kind"] == "union":
        fams = set(family(types, m) for m in t["members"])
        if len(fams) != 1:
            fail("union %s mixes value families %s" % (name, sorted(fams)))
        return fams.pop()
    if t["kind"] == "complex":
        return family(types, t["simple"]) if "simple" in t else None
    fam = FAMILY[t["base"]]
    if fam == "decimal" and "totalDigits" not in t["facets"] and "fractionDigits" not in t["facets"]:
        return "decimaltext"
    return fam


def enum_info(types, name):
    """(enumeration values, open) of a simple type; unions combine their
    members, a member without enumeration makes the type open."""
    if name.startswith("xs:"):
        return [], True
    t = types[name]
    if t["kind"] == "union":
        values = []
        is_open = False
        for m in t["members"]:
            v, o = enum_info(types, m)
            values.extend(x for x in v if x not in values)
            is_open = is_open or o
        return values, is_open
    if t["kind"] == "complex":
        return enum_info(types, t["simple"]) if "simple" in t else ([], True)
    if "enumeration" in t:
        return list(t["enumeration"]), False
    return [], True


# ---- shape of a complex type in one context ----

def element_names(p, acc):
    if p["k"] == "element":
        if p["name"] not in acc:
            acc.append(p["name"])
    else:
        for i in p["items"]:
            element_names(i, acc)
    return acc


def requires_element(p):
    """True if every match of the particle contains at least one element."""
    if p["min"] < 1:
        return False
    if p["k"] == "element":
        return True
    if p["k"] == "sequence":
        return any(requires_element(i) for i in p["items"])
    return bool(p["items"]) and all(requires_element(i) for i in p["items"])


def has_anchor(p):
    return any(requires_element(i) for i in p["items"])


class Shape(object):
    def __init__(self):
        self.fields = []      # [name]
        self.field = {}       # name -> (type, max)
        self.children = None  # [name] or None
        self.child = {}       # name -> type
        self.group = None     # (Shape, min, max)

    def add_field(self, name, etype, mx, where):
        if name in self.field:
            old_type, old_max = self.field[name]
            if old_type != etype:
                fail("%s: element %s with different types in one tree" % (where, name))
            self.field[name] = (etype, add(old_max, mx))
        else:
            self.fields.append(name)
            self.field[name] = (etype, mx)


def shape_of(particle, where):
    s = Shape()
    if particle is not None:
        walk(particle, 1, s, where)
    clash = set(s.fields) & set(s.children or [])
    if s.group is not None:
        clash |= set(s.fields) & set(s.group[0].fields)
    if clash:
        fail("%s: %s both field and child or group member" % (where, sorted(clash)))
    return s


def walk(p, factor, s, where):
    if p["k"] == "element":
        s.add_field(p["name"], p["type"], mul(factor, p["max"]), where)
        return
    names = element_names(p, [])
    if p["max"] != 1 and len(names) > 1:
        if p["k"] == "sequence" and has_anchor(p):
            if s.group is not None:
                fail("%s: more than one repeated group" % where)
            inner = Shape()
            for i in p["items"]:
                walk(i, 1, inner, where + "/group")
            s.group = (inner, p["min"], p["max"])
            s.fields.append("#group")
        else:
            if s.children is not None:
                fail("%s: more than one region of ordered children" % where)
            s.children = []
            collect_children(p, s, where)
            s.fields.append("#children")
        return
    for i in p["items"]:
        walk(i, mul(factor, p["max"]), s, where)


def collect_children(p, s, where):
    if p["k"] == "element":
        if p["name"] in s.child and s.child[p["name"]] != p["type"]:
            fail("%s: child %s with different types" % (where, p["name"]))
        if p["name"] not in s.child:
            s.children.append(p["name"])
            s.child[p["name"]] = p["type"]
        return
    for i in p["items"]:
        collect_children(i, s, where)


# ---- merging ----

def merge_order(orders):
    """One order containing every list as a subsequence, or None on a cycle.
    Ties are broken by first appearance."""
    rank = {}
    edges = {}
    for o in orders:
        for i, n in enumerate(o):
            rank.setdefault(n, len(rank))
            edges.setdefault(n, set())
            if i > 0:
                edges[o[i - 1]].add(n)
    indeg = dict((n, 0) for n in edges)
    for n in edges:
        for m in edges[n]:
            indeg[m] += 1
    ready = sorted([n for n in indeg if indeg[n] == 0], key=lambda n: rank[n])
    result = []
    while ready:
        n = ready.pop(0)
        result.append(n)
        for m in edges[n]:
            indeg[m] -= 1
            if indeg[m] == 0:
                ready.append(m)
        ready.sort(key=lambda x: rank[x])
    return result if len(result) == len(edges) else None


class Merger(object):
    def __init__(self, contexts, exceptions):
        self.contexts = contexts
        self.published = set(c["context"]["id"] for c in contexts if c["context"]["publish"])
        self.exceptions = exceptions
        self.by_name = {}
        for ctx in contexts:
            for name, t in ctx["types"].items():
                self.by_name.setdefault(name, []).append((ctx["context"]["id"], ctx["types"], t))
        self.classes = {}
        self.conflicts = {}

    def problem(self, name, msg):
        self.conflicts.setdefault(name, []).append(msg)

    def compatible(self, a_types, a, b_types, b):
        if a == b:
            return True
        a_simple = a.startswith("xs:") or kind_of(a_types[a]) == "simple"
        b_simple = b.startswith("xs:") or kind_of(b_types[b]) == "simple"
        return a_simple and b_simple and family(a_types, a) == family(b_types, b)

    def pub(self, cids):
        return any(c in self.published for c in cids)

    def list_flag(self, maxima):
        """maxima: {cid: max}; published contexts decide when present there."""
        chosen = [m for c, m in maxima.items() if c in self.published] or list(maxima.values())
        return any(m == -1 or m > 1 for m in chosen)

    def run(self):
        for name in sorted(self.by_name):
            self.merge_type(name, self.by_name[name])
        return self.classes, self.conflicts

    def merge_type(self, name, members):
        kinds = set(kind_of(t) for _, _, t in members)
        if len(kinds) != 1:
            self.problem(name, "kind differs: " + ", ".join(sorted(kinds)))
            return
        kind = kinds.pop()
        cids = [cid for cid, _, _ in members]
        cls = {"kind": kind, "contexts": cids, "published": self.pub(cids)}
        if kind == "simple":
            fams = set(family(types, name) for _, types, _ in members)
            if len(fams) != 1:
                self.problem(name, "value family differs: " + ", ".join(sorted(fams)))
                return
            cls["family"] = fams.pop()
            values = []
            where = {}
            opens = {}
            for cid, types, _ in members:
                vals, opens[cid] = enum_info(types, name)
                for v in vals:
                    if v not in where:
                        values.append(v)
                        where[v] = []
                    where[v].append(cid)
            if values:
                cls["enumeration"] = [{"value": v, "published": self.pub(where[v])} for v in values]
                chosen = [c for c in opens if c in self.published] or list(opens)
                cls["open"] = any(opens[c] for c in chosen)
            self.classes[name] = cls
            return
        cls["attributes"] = self.merge_attributes(name, members)
        if kind == "simplecontent":
            fams = set(family(types, t["simple"]) for _, types, t in members)
            if len(fams) != 1:
                self.problem(name, "simple content family differs: " + ", ".join(sorted(fams)))
                return
            cls["family"] = fams.pop()
            cls["simple"] = sorted(set(t["simple"] for _, _, t in members))
            self.classes[name] = cls
            return
        decision = self.exceptions.get(name, {})
        if decision and decision.get("decision") != "widen":
            fail("merge-exceptions.json: unknown decision %r for %s" % (decision.get("decision"), name))
        widen = decision.get("elements", {}) if decision else {}
        shapes = [(cid, types, shape_of(t["particle"], "%s (%s)" % (name, cid))) for cid, types, t in members]
        if widen:
            cls["widened"] = widen
        self.merge_shapes(name, cls, shapes, widen)
        for n in widen:
            if not any(f["name"] == n for f in cls["fields"]):
                fail("merge-exceptions.json: %s has no element %s" % (name, n))
        self.classes[name] = cls

    def merge_attributes(self, name, members):
        attrs = {}
        orders = []
        for cid, types, t in members:
            orders.append([a["name"] for a in t["attributes"]])
            for a in t["attributes"]:
                e = attrs.setdefault(a["name"], {"types": {}, "uses": {}})
                e["types"][cid] = (types, a["type"])
                e["uses"][cid] = a["use"]
        result = []
        scope = [cid for cid, _, _ in members if cid in self.published] or [cid for cid, _, _ in members]
        for n in merge_order(orders) or sorted(attrs):
            e = attrs[n]
            self.check_types(name, "attribute " + n, e["types"])
            required = all(e["uses"].get(cid) == "required" for cid in scope)
            result.append({"name": n, "type": self.pick(e["types"]), "types": self.type_map(e["types"]),
                           "use": "required" if required else "optional",
                           "published": self.pub(e["types"].keys())})
        return result

    def type_map(self, types):
        return dict(sorted((cid, t) for cid, (_, t) in types.items()))

    def pick(self, types):
        """Type name of the last published context that has it (else the last)."""
        chosen = [c for c in types if c in self.published] or list(types)
        return types[chosen[-1]][1]

    def check_types(self, name, what, types):
        items = list(types.items())
        first_cid, (first_types, first) = items[0]
        for cid, (t, tname) in items[1:]:
            if not self.compatible(first_types, first, t, tname):
                self.problem(name, "%s: type %s (%s) / %s (%s)" % (what, first, first_cid, tname, cid))

    def merge_shapes(self, name, cls, shapes, widen):
        fields = {}
        orders = []
        child_names = None
        child = {}
        groups = []
        # an element that is an ordered child in one context is one in every
        # context (X84 restricts some text containers to a single element name)
        any_child = set()
        for _, _, s in shapes:
            any_child.update(s.children or [])
        for cid, types, s in shapes:
            orders.append([n for n in s.fields if n not in any_child])
            for n in s.fields:
                if n in any_child:
                    child_names = child_names or []
                    if n not in child:
                        child_names.append(n)
                        child[n] = {}
                    child[n][cid] = (types, s.field[n][0])
                    continue
                if n.startswith("#"):
                    continue
                etype, mx = s.field[n]
                if n in widen and etype != widen[n]:
                    if not self.widen_ok(types, etype, widen[n]):
                        self.problem(name, "element %s: %s does not fit into %s" % (n, etype, widen[n]))
                    etype = widen[n]
                e = fields.setdefault(n, {"types": {}, "max": {}})
                e["types"][cid] = (types, etype)
                e["max"][cid] = mx
            if s.children is not None:
                child_names = child_names or []
                for n in s.children:
                    if n not in child:
                        child_names.append(n)
                        child[n] = {}
                    child[n][cid] = (types, s.child[n])
            if s.group is not None:
                groups.append((cid, types, s.group))
        all_children = set(child)
        group_members = set()
        for _, _, g in groups:
            group_members.update(n for n in g[0].fields if not n.startswith("#"))
            group_members.update(g[0].children or [])
        for n in fields:
            if n in all_children:
                self.problem(name, "element %s is a field in one context and a child in another" % n)
            if n in group_members:
                self.problem(name, "element %s is a field in one context and a group member in another" % n)
        order = merge_order(orders)
        if order is None:
            self.problem(name, "field order differs between contexts")
            order = []
            for o in orders:
                order.extend(n for n in o if n not in order)
        out_fields = []
        for n in order:
            if n == "#children":
                out_fields.append({"name": "#children"})
                continue
            if n == "#group":
                gname = name + "/group"
                out_fields.append({"name": "#group", "type": gname, "list": True,
                                   "published": self.pub([g[0] for g in groups])})
                continue
            e = fields[n]
            self.check_types(name, "element " + n, e["types"])
            out_fields.append({"name": n, "type": self.pick(e["types"]), "types": self.type_map(e["types"]),
                               "list": self.list_flag(e["max"]), "published": self.pub(e["types"].keys())})
        cls["fields"] = out_fields
        if child_names is not None:
            cls["children"] = []
            for n in child_names:
                self.check_types(name, "child " + n, child[n])
                cls["children"].append({"name": n, "type": self.pick(child[n]),
                                        "types": self.type_map(child[n]),
                                        "published": self.pub(child[n].keys())})
        if groups:
            gcls = {"kind": "group", "owner": name, "contexts": [g[0] for g in groups],
                    "published": self.pub([g[0] for g in groups]), "attributes": []}
            self.merge_shapes(name + "/group", gcls, [(cid, types, g[0]) for cid, types, g in groups], {})
            self.classes[name + "/group"] = gcls

    def widen_ok(self, types, narrow, wide):
        """Every child of the narrow type exists in the wide type of some
        context with a compatible type and at least the same cardinality;
        attributes alike."""
        if narrow.startswith("xs:") or kind_of(types[narrow]) != "complex":
            return False
        ns = shape_of(types[narrow]["particle"], narrow)
        nattrs = dict((a["name"], a["type"]) for a in types[narrow]["attributes"])
        for cid, wtypes, w in self.by_name.get(wide, []):
            if kind_of(w) != "complex":
                continue
            ws = shape_of(w["particle"], wide)
            wattrs = dict((a["name"], a["type"]) for a in w["attributes"])
            if ns.children or ns.group or ws.children or ws.group:
                continue
            ok = True
            for n in ns.fields:
                if n not in ws.field:
                    ok = False
                    break
                nt, nmax = ns.field[n]
                wt, wmax = ws.field[n]
                if not self.compatible(types, nt, wtypes, wt) or (wmax != -1 and (nmax == -1 or nmax > wmax)):
                    ok = False
                    break
            if ok and all(n in wattrs and self.compatible(types, t, wtypes, wattrs[n]) for n, t in nattrs.items()):
                return True
        return False


def main(argv):
    args = argv[1:]
    if len(args) > 1 or any(a != "--check" for a in args):
        fail("usage: merge-gaeb.py [--check]")
    contexts = load_contexts()
    exceptions = {}
    if os.path.exists(EXCEPTIONS):
        exceptions = json.load(io.open(EXCEPTIONS, encoding="utf-8")).get("types", {})
    for name in exceptions:
        if not any(name in c["types"] for c in contexts):
            fail("merge-exceptions.json names unknown type %s" % name)
    classes, conflicts = Merger(contexts, exceptions).run()
    result = {"contexts": [c["context"] for c in contexts],
              "roots": sorted(set(c["root"]["type"] for c in contexts)),
              "classes": dict(sorted(classes.items()))}
    text = json.dumps(result, indent=1, ensure_ascii=True, sort_keys=False) + "\n"
    digest = hashlib.sha256(text.encode("utf-8")).hexdigest() + "  gaeb-merged.json\n"
    counts = {}
    for c in classes.values():
        counts[c["kind"]] = counts.get(c["kind"], 0) + 1
    print("merge-gaeb: %d classes (%s), %d published, %d conflicts" % (
        len(classes), ", ".join("%s %d" % kv for kv in sorted(counts.items())),
        sum(1 for c in classes.values() if c["published"]), len(conflicts)))
    for name in sorted(conflicts):
        print("  %s" % name)
        for p in conflicts[name]:
            print("    " + p)
    if conflicts:
        return 1
    if "--check" in args:
        current = io.open(HASHES, encoding="utf-8").read() if os.path.exists(HASHES) else ""
        if current.replace("\r\n", "\n") != digest:
            sys.stderr.write("merge-gaeb: merged.sha256 is not up to date\n")
            return 1
        print("merge-gaeb: up to date")
        return 0
    io.open(os.path.join(OUT, "gaeb-merged.json"), "w", encoding="utf-8", newline="\n").write(text)
    io.open(HASHES, "w", encoding="utf-8", newline="\n").write(digest)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
