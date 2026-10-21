#!/usr/bin/env python3
"""Reads the GAEB DA XML schemas of the local Specification/ folder (never
part of the repository), verifies the checksums of manifest.json and writes
one structure description per schema context (version, edition, phase) to
tools/schema/out/<id>.json (git-ignored). The checksums of these outputs are
kept in out.sha256 (committed), so a change of the extraction shows up in
the history although the outputs themselves are not committed.

A context description holds the namespace, the root element and every type
reachable from it, with xs:redefine resolved in that context: the result
is the effective content model of the phase, not "Lib plus delta". Redefined
schemas must be chameleon schemas without own target namespace and without
global elements (true for the Lib of every edition); the 50.x chains
(50.1 -> 50 -> Lib5x) need this relaxed when their contexts are added.
Complex types keep their full particle tree (nested sequence and choice
with minOccurs/maxOccurs on every particle, schema order), attributes,
mixed and identity constraints (xs:unique; none is active in the current
schemas); simple types are flattened to a built-in base with their facets.
Documentation texts are never copied.

Supported XSD constructs (anything else stops the extraction with its
location, never guessed):
  schema: element, complexType, simpleType, redefine (no include/import)
  redefine: complexType and simpleType deriving from themselves
  complexType: sequence | choice | simpleContent | complexContent | empty,
    attributes; attribute mixed
  complexContent: restriction | extension with an optional particle and
    attributes
  simpleContent: extension with attributes
  sequence/choice: element, sequence, choice; minOccurs, maxOccurs
  element: name, type or anonymous complexType/simpleType, minOccurs,
    maxOccurs, unique (selector, field)
  attribute: name, type or anonymous simpleType, use, default
  simpleType: restriction (enumeration, fractionDigits, totalDigits,
    maxLength, minLength, length, maxInclusive, minInclusive, maxExclusive,
    minExclusive, pattern, whiteSpace) | union (memberTypes)

Usage:
  python tools/schema/extract-gaeb-xsd.py                    extract all contexts
  python tools/schema/extract-gaeb-xsd.py --check            exit 1 if an output or
                                                             out.sha256 differs
  python tools/schema/extract-gaeb-xsd.py --update-manifest  recompute the file
                                                             checksums in manifest.json
"""

import copy
import hashlib
import io
import json
import os
import sys
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(HERE, "out")
HASHES = os.path.join(HERE, "out.sha256")
XSD = "http://www.w3.org/2001/XMLSchema"
XS = "{" + XSD + "}"

BUILTIN = {"string", "normalizedString", "token", "decimal", "integer", "nonNegativeInteger",
           "positiveInteger", "float", "date", "time", "gYearMonth", "ID", "IDREF", "NCName",
           "boolean", "base64Binary"}
FACETS = {"enumeration", "fractionDigits", "totalDigits", "maxLength", "minLength", "length",
          "maxInclusive", "minInclusive", "maxExclusive", "minExclusive", "pattern", "whiteSpace"}


def fail(msg):
    sys.stderr.write("extract-gaeb-xsd: " + msg + "\n")
    sys.exit(2)


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def local(tag):
    return tag[len(XS):] if tag.startswith(XS) else tag


def children(node):
    """Child elements without annotations; foreign elements stop."""
    result = []
    for c in node:
        if not isinstance(c.tag, str):
            continue  # comment
        if not c.tag.startswith(XS):
            fail("foreign element %s" % c.tag)
        if c.tag != XS + "annotation":
            result.append(c)
    return result


def check_attrs(node, allowed, where):
    for a in node.attrib:
        if a not in allowed:
            fail("%s: unsupported attribute %s on %s" % (where, a, local(node.tag)))


def occurs(node, where):
    mn = node.get("minOccurs", "1")
    mx = node.get("maxOccurs", "1")
    try:
        return int(mn), (-1 if mx == "unbounded" else int(mx))
    except ValueError:
        fail("%s: bad occurrence %s/%s" % (where, mn, mx))


class Context(object):
    def __init__(self, folder, files):
        self.folder = folder
        self.files = files            # file name -> bytes (verified)
        self.raw = {}                 # type name -> raw definition
        self.serial = 0
        self.namespace = None
        self.root = None

    # ---- loading ----

    def qname(self, text, nsmap, where):
        prefix, _, name = text.rpartition(":")
        uri = nsmap.get(prefix)
        if uri == XSD:
            if name not in BUILTIN:
                fail("%s: unsupported built-in type xs:%s" % (where, name))
            return "xs:" + name
        if prefix and uri is None:
            fail("%s: unknown prefix in %r" % (where, text))
        if uri is not None and uri != self.namespace:
            fail("%s: reference %r into a foreign namespace" % (where, text))
        # the Lib has no target namespace (chameleon): every other reference
        # is a type of the schema set
        return name

    def parse(self, name):
        if name not in self.files:
            fail("schema %s is not listed in the manifest" % name)
        data = self.files[name]
        nsmap = {}
        for _, (prefix, uri) in ET.iterparse(io.BytesIO(data), events=["start-ns"]):
            if prefix in nsmap and nsmap[prefix] != uri:
                fail("%s: prefix %s bound twice" % (name, prefix))
            nsmap[prefix] = uri
        return ET.fromstring(data), nsmap

    def load(self, name, main):
        root, nsmap = self.parse(name)
        check_attrs(root, {"targetNamespace", "elementFormDefault", "attributeFormDefault"}, name)
        if root.get("elementFormDefault") != "qualified":
            fail("%s: elementFormDefault must be qualified" % name)
        if root.get("attributeFormDefault", "unqualified") != "unqualified":
            fail("%s: attributeFormDefault must be unqualified" % name)
        if main:
            self.namespace = root.get("targetNamespace")
            if not self.namespace:
                fail("%s: main schema without targetNamespace" % name)
        elif root.get("targetNamespace"):
            fail("%s: redefined schema with own targetNamespace" % name)
        items = children(root)
        # redefined schemas first, then the redefinitions on top of them
        for c in items:
            if c.tag == XS + "redefine":
                check_attrs(c, {"schemaLocation"}, name)
                self.load(c.get("schemaLocation"), False)
                for d in children(c):
                    self.redefine(d, nsmap, name)
        for c in items:
            tag = local(c.tag)
            if tag == "redefine":
                continue
            if tag == "element":
                if not main or self.root is not None:
                    fail("%s: unexpected global element" % name)
                check_attrs(c, {"name", "type"}, name)
                self.root = {"name": c.get("name"), "type": self.qname(c.get("type"), nsmap, name)}
                if children(c):
                    fail("%s: global element with content" % name)
            elif tag in ("complexType", "simpleType"):
                tname = c.get("name")
                if tname in self.raw:
                    fail("%s: type %s defined twice" % (name, tname))
                self.raw[tname] = self.type_def(c, nsmap, tname)
            else:
                fail("%s: unsupported top-level %s" % (name, tag))

    def redefine(self, node, nsmap, where):
        tname = node.get("name")
        if tname not in self.raw:
            fail("%s: redefinition of unknown type %s" % (where, tname))
        self.serial += 1
        previous = "%s#%d" % (tname, self.serial)
        self.raw[previous] = self.raw.pop(tname)
        definition = self.type_def(node, nsmap, tname)
        if definition.get("derivation", {}).get("base") != tname:
            fail("%s: redefinition of %s does not derive from itself" % (where, tname))
        definition["derivation"]["base"] = previous
        self.raw[tname] = definition

    def type_def(self, node, nsmap, path):
        if node.tag == XS + "simpleType":
            return self.simple_def(node, nsmap, path)
        return self.complex_def(node, nsmap, path)

    def simple_def(self, node, nsmap, path):
        check_attrs(node, {"name"}, path)
        items = children(node)
        if len(items) != 1:
            fail("%s: simpleType needs one derivation" % path)
        d = items[0]
        if d.tag == XS + "union":
            check_attrs(d, {"memberTypes"}, path)
            if children(d):
                fail("%s: union with anonymous members" % path)
            return {"kind": "union", "members": [self.qname(m, nsmap, path) for m in d.get("memberTypes").split()]}
        if d.tag != XS + "restriction":
            fail("%s: unsupported simpleType derivation %s" % (path, local(d.tag)))
        check_attrs(d, {"base"}, path)
        facets = {}
        fixed = []
        enum = []
        patterns = []
        for f in children(d):
            fname = local(f.tag)
            if fname not in FACETS:
                fail("%s: unsupported facet %s" % (path, fname))
            check_attrs(f, {"value", "fixed"}, path)
            if fname == "enumeration":
                enum.append(f.get("value"))
            elif fname == "pattern":
                patterns.append(f.get("value"))
            else:
                if fname in facets:
                    fail("%s: facet %s twice" % (path, fname))
                facets[fname] = f.get("value")
                if f.get("fixed") == "true":
                    fixed.append(fname)
        result = {"kind": "simple", "derivation": {"base": self.qname(d.get("base"), nsmap, path)},
                  "facets": facets}
        if fixed:
            result["fixed"] = fixed
        if enum:
            result["enumeration"] = enum
        if patterns:
            result["patterns"] = patterns
        return result

    def anonymous(self, node, nsmap, path):
        if path in self.raw:
            fail("%s: anonymous type name clash" % path)
        self.raw[path] = self.type_def(node, nsmap, path)
        return path

    def attributes(self, nodes, nsmap, path):
        result = []
        for a in nodes:
            check_attrs(a, {"name", "type", "use", "default"}, path)
            apath = path + "/@" + a.get("name")
            inner = children(a)
            if a.get("type"):
                if inner:
                    fail("%s: attribute with type and content" % apath)
                atype = self.qname(a.get("type"), nsmap, apath)
            elif len(inner) == 1 and inner[0].tag == XS + "simpleType":
                atype = self.anonymous(inner[0], nsmap, apath)
            else:
                fail("%s: attribute without type" % apath)
            use = a.get("use", "optional")
            if use not in ("optional", "required", "prohibited"):
                fail("%s: bad use %s" % (apath, use))
            entry = {"name": a.get("name"), "type": atype, "use": use}
            if a.get("default") is not None:
                entry["default"] = a.get("default")
            result.append(entry)
        return result

    def split_content(self, nodes, path):
        particle = None
        attrs = []
        for n in nodes:
            tag = local(n.tag)
            if tag in ("sequence", "choice"):
                if particle is not None or attrs:
                    fail("%s: unexpected %s" % (path, tag))
                particle = n
            elif tag == "attribute":
                attrs.append(n)
            else:
                fail("%s: unsupported %s in complex content" % (path, tag))
        return particle, attrs

    def complex_def(self, node, nsmap, path):
        check_attrs(node, {"name", "mixed"}, path)
        mixed = node.get("mixed", "false") == "true"
        items = children(node)
        if len(items) == 1 and items[0].tag in (XS + "simpleContent", XS + "complexContent"):
            content = items[0]
            check_attrs(content, set(), path)
            inner = children(content)
            if len(inner) != 1:
                fail("%s: %s needs one derivation" % (path, local(content.tag)))
            d = inner[0]
            method = local(d.tag)
            if method not in ("extension", "restriction"):
                fail("%s: unsupported derivation %s" % (path, method))
            check_attrs(d, {"base"}, path)
            base = self.qname(d.get("base"), nsmap, path)
            if content.tag == XS + "simpleContent":
                if method != "extension":
                    fail("%s: simpleContent restriction is not supported" % path)
                particle, attrs = self.split_content(children(d), path)
                if particle is not None:
                    fail("%s: particle in simpleContent" % path)
                return {"kind": "complex", "mixed": mixed,
                        "derivation": {"content": "simple", "method": method, "base": base},
                        "attributes": self.attributes(attrs, nsmap, path)}
            particle, attrs = self.split_content(children(d), path)
            return {"kind": "complex", "mixed": mixed,
                    "derivation": {"content": "complex", "method": method, "base": base},
                    "particle": self.particle(particle, nsmap, path) if particle is not None else None,
                    "attributes": self.attributes(attrs, nsmap, path)}
        particle, attrs = self.split_content(items, path)
        return {"kind": "complex", "mixed": mixed,
                "particle": self.particle(particle, nsmap, path) if particle is not None else None,
                "attributes": self.attributes(attrs, nsmap, path)}

    def particle(self, node, nsmap, path):
        tag = local(node.tag)
        mn, mx = occurs(node, path)
        if tag in ("sequence", "choice"):
            check_attrs(node, {"minOccurs", "maxOccurs"}, path)
            items = [self.particle(c, nsmap, path) for c in children(node)]
            return {"k": tag, "min": mn, "max": mx, "items": items}
        if tag != "element":
            fail("%s: unsupported particle %s" % (path, tag))
        check_attrs(node, {"name", "type", "minOccurs", "maxOccurs"}, path)
        name = node.get("name")
        epath = path + "/" + name
        inner = children(node)
        unique = [c for c in inner if c.tag == XS + "unique"]
        inner = [c for c in inner if c.tag != XS + "unique"]
        if node.get("type"):
            if inner:
                fail("%s: element with type and content" % epath)
            etype = self.qname(node.get("type"), nsmap, epath)
        elif len(inner) == 1 and inner[0].tag in (XS + "complexType", XS + "simpleType"):
            etype = self.anonymous(inner[0], nsmap, epath)
        else:
            fail("%s: element without type" % epath)
        result = {"k": "element", "name": name, "type": etype, "min": mn, "max": mx}
        if unique:
            result["unique"] = [self.unique(u, epath) for u in unique]
        return result

    def unique(self, node, path):
        check_attrs(node, {"name"}, path)
        selector = None
        fields = []
        for c in children(node):
            check_attrs(c, {"xpath"}, path)
            if c.tag == XS + "selector" and selector is None:
                selector = c.get("xpath")
            elif c.tag == XS + "field":
                fields.append(c.get("xpath"))
            else:
                fail("%s: unsupported %s in unique" % (path, local(c.tag)))
        if selector is None or not fields:
            fail("%s: incomplete unique" % path)
        return {"name": node.get("name"), "selector": selector, "fields": fields}

    # ---- resolution ----

    def resolve(self, name, stack=()):
        """Effective definition of a type (derivations applied)."""
        if name.startswith("xs:"):
            return {"kind": "simple", "base": name, "facets": {}}
        if name in stack:
            fail("circular derivation of %s" % name)
        if name not in self.raw:
            fail("unknown type %s" % name)
        raw = self.raw[name]
        stack = stack + (name,)
        if raw["kind"] == "union":
            return {"kind": "union", "members": raw["members"]}
        if raw["kind"] == "simple":
            base = self.resolve(raw["derivation"]["base"], stack)
            if base["kind"] != "simple":
                fail("%s: restriction of a non-atomic type" % name)
            result = {"kind": "simple", "base": base["base"], "facets": dict(base["facets"])}
            result["facets"].update(raw["facets"])
            if raw.get("enumeration"):
                result["enumeration"] = raw["enumeration"]
            elif base.get("enumeration"):
                result["enumeration"] = base["enumeration"]
            patterns = list(base.get("patterns", []))
            if raw.get("patterns"):
                patterns.append(raw["patterns"])  # steps are ANDed, values in a step ORed
            if patterns:
                result["patterns"] = patterns
            fixed = sorted(set(base.get("fixed", [])) | set(raw.get("fixed", [])))
            if fixed:
                result["fixed"] = fixed
            return result
        d = raw.get("derivation")
        if d is None:
            return {"kind": "complex", "mixed": raw["mixed"], "particle": copy.deepcopy(raw["particle"]),
                    "attributes": copy.deepcopy(raw["attributes"])}
        base = self.resolve(d["base"], stack)
        if d["content"] == "simple":
            if base["kind"] == "complex":
                if "simple" not in base:
                    fail("%s: simpleContent on a complex type with element content" % name)
                simple = base["simple"]
                attrs = merge_attributes(base["attributes"], raw["attributes"], "extension", name)
            else:
                simple = d["base"]
                attrs = merge_attributes([], raw["attributes"], "extension", name)
            return {"kind": "complex", "mixed": raw["mixed"], "simple": simple, "attributes": attrs}
        if base["kind"] != "complex" or "simple" in base:
            fail("%s: complexContent on a type without element content" % name)
        if d["method"] == "extension" and raw["mixed"] != base["mixed"]:
            fail("%s: extension changes mixed" % name)
        if d["method"] == "restriction":
            particle = copy.deepcopy(raw["particle"])
        elif base["particle"] is None:
            particle = copy.deepcopy(raw["particle"])
        elif raw["particle"] is None:
            particle = base["particle"]
        else:
            particle = {"k": "sequence", "min": 1, "max": 1,
                        "items": [base["particle"], copy.deepcopy(raw["particle"])]}
        return {"kind": "complex", "mixed": raw["mixed"], "particle": particle,
                "attributes": merge_attributes(base["attributes"], raw["attributes"], d["method"], name)}

    def describe(self):
        if self.root is None:
            fail("no root element")
        types = {}
        todo = [self.root["type"]]
        while todo:
            name = todo.pop()
            if name in types or name.startswith("xs:"):
                continue
            t = self.resolve(name)
            types[name] = t
            if t["kind"] == "union":
                todo.extend(t["members"])
            elif t["kind"] == "complex":
                if "simple" in t:
                    todo.append(t["simple"])
                else:
                    todo.extend(element_types(t["particle"]))
                todo.extend(a["type"] for a in t["attributes"])
        builtins = set("xs:" + b for b in BUILTIN)
        for t in types.values():
            if t["kind"] == "simple" and t["base"] not in builtins:
                fail("unresolved base %s" % t["base"])
        return {"namespace": self.namespace, "root": self.root,
                "types": dict(sorted(types.items()))}


def merge_attributes(base, own, method, where):
    result = [dict(a) for a in base]
    index = dict((a["name"], i) for i, a in enumerate(result))
    for a in own:
        if a["name"] in index:
            if method == "extension":
                fail("%s: extension redeclares attribute %s" % (where, a["name"]))
            result[index[a["name"]]] = dict(a)
        else:
            if method == "restriction" and a["use"] != "prohibited":
                fail("%s: restriction adds attribute %s" % (where, a["name"]))
            index[a["name"]] = len(result)
            result.append(dict(a))
    return [a for a in result if a["use"] != "prohibited"]


def element_types(particle):
    if particle is None:
        return []
    if particle["k"] == "element":
        return [particle["type"]]
    result = []
    for p in particle["items"]:
        result.extend(element_types(p))
    return result


def load_manifest():
    return json.load(io.open(os.path.join(HERE, "manifest.json"), encoding="utf-8"))


def spec_root(manifest):
    root = os.path.join(REPO, manifest["root"])
    if not os.path.isdir(root):
        fail("%s not found (the specification is local only)" % root)
    return root


def read_files(root, ctx):
    files = {}
    for name, digest in sorted(ctx["files"].items()):
        path = os.path.join(root, ctx["folder"], name)
        if not os.path.exists(path):
            fail("%s: missing %s" % (ctx["id"], path))
        data = open(path, "rb").read()
        if sha256(data) != digest:
            fail("%s: checksum mismatch for %s" % (ctx["id"], name))
        files[name] = data
    return files


def update_manifest():
    manifest = load_manifest()
    root = spec_root(manifest)
    for ctx in manifest["contexts"]:
        for name in ctx["files"]:
            ctx["files"][name] = sha256(open(os.path.join(root, ctx["folder"], name), "rb").read())
    text = json.dumps(manifest, indent=1, ensure_ascii=True) + "\n"
    io.open(os.path.join(HERE, "manifest.json"), "w", encoding="utf-8", newline="\n").write(text)
    print("extract-gaeb-xsd: manifest.json updated (%d contexts)" % len(manifest["contexts"]))
    return 0


def main(argv):
    args = argv[1:]
    if len(args) > 1 or any(a not in ("--check", "--update-manifest") for a in args):
        fail("usage: extract-gaeb-xsd.py [--check | --update-manifest]")
    if "--update-manifest" in args:
        return update_manifest()
    check = "--check" in args
    manifest = load_manifest()
    root = spec_root(manifest)
    hashes = []
    status = 0
    if not check:
        os.makedirs(OUT, exist_ok=True)
    for ctx in manifest["contexts"]:
        c = Context(ctx["folder"], read_files(root, ctx))
        c.load(ctx["main"], True)
        data = c.describe()
        data = dict([("context", {"id": ctx["id"], "version": ctx["version"], "edition": ctx["edition"],
                                  "phase": ctx["phase"], "publish": ctx["publish"]})] + list(data.items()))
        text = json.dumps(data, indent=1, ensure_ascii=True) + "\n"
        hashes.append("%s  %s.json" % (sha256(text.encode("utf-8")), ctx["id"]))
        out = os.path.join(OUT, ctx["id"] + ".json")
        if check:
            current = io.open(out, encoding="utf-8").read() if os.path.exists(out) else None
            if current != text:
                sys.stderr.write("extract-gaeb-xsd: %s is not up to date\n" % out)
                status = 1
        else:
            io.open(out, "w", encoding="utf-8", newline="\n").write(text)
            print("extract-gaeb-xsd: %s (%d types)" % (ctx["id"], len(data["types"])))
    hash_text = "\n".join(hashes) + "\n"
    if check:
        current = io.open(HASHES, encoding="utf-8").read() if os.path.exists(HASHES) else None
        if current is None or current.replace("\r\n", "\n") != hash_text:
            sys.stderr.write("extract-gaeb-xsd: out.sha256 is not up to date\n")
            status = 1
        if status == 0:
            print("extract-gaeb-xsd: %d contexts up to date" % len(hashes))
    else:
        io.open(HASHES, "w", encoding="utf-8", newline="\n").write(hash_text)
    return status


if __name__ == "__main__":
    sys.exit(main(sys.argv))
