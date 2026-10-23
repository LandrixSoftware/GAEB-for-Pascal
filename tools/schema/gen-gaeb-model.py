#!/usr/bin/env python3
"""Generates the GAEB DA XML syntax model from tools/schema/out/gaeb-merged.json
(written by merge-gaeb.py):

  source/LandrixGaebXmlModel.pas   one class per schema type with element or
                                   simple content, typed lists, group classes
  source/LandrixGaebXmlCodes.pas   Pascal enums for enumerated simple types
                                   with conversion from and to the codes
  source/LandrixGaebXmlReader.pas  reader on the pull reader of LandrixXml
                                   (context in LandrixGaebXmlReadBase)
  source/LandrixGaebXmlProfiles.pas slots per target and class: allowed
                                   members, child rows, fraction digits
  source/LandrixGaebXmlWriter.pas  writer on the streaming writer of
                                   LandrixXml (context in LandrixGaebXmlWriteBase)

Only published contexts (3.2, 3.3) make it into the units; members that exist
only in the 3.4 beta are left out (plan, decisions of 21.10.2026).

Mapping (plan 7.1 to 7.4, decisions of 21.10.2026):
- complex type          -> class TLandrixGaebXml<Name> (TLandrixGaebXmlNode);
                           single complex children are created on first
                           access (never nil), HasX tells presence without
                           creating; repeated ones are typed owning lists
- repeated choice       -> Children (TLandrixGaebXmlNodeList, document order)
                           with AddX helpers per element
- repeated sequence with a mandatory member -> group class in a typed list
- bounded decimal       -> TLandrixGaebDecimal; tgDecimal -> TLandrixGaebDecimalText
- any other simple type -> TLandrixGaebString, lexical text, '' = absent
- tgImage               -> Base64 text as UTF-8 bytes (never UTF-16)

Names come from tools/schema/names.json (committed). A name the table does
not hold stops the generator; --update-names adds the missing names by the
default rules and removes names that are no longer used, so every change of
a public name shows up in the history.

Deterministic ASCII output with CRLF.

Usage:
  python tools/schema/gen-gaeb-model.py                 write the units
  python tools/schema/gen-gaeb-model.py --check         exit 1 if a unit differs
  python tools/schema/gen-gaeb-model.py --update-names  update names.json, then write
"""

import io
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
MERGED = os.path.join(HERE, "out", "gaeb-merged.json")
NAMES = os.path.join(HERE, "names.json")
MODEL_UNIT = os.path.join(ROOT, "source", "LandrixGaebXmlModel.pas")
CODES_UNIT = os.path.join(ROOT, "source", "LandrixGaebXmlCodes.pas")

CLASS_PREFIX = "TLandrixGaebXml"

# simple types mapped to hand-written types of LandrixGaebTypes
MAPPED_ENUMS = {"tgDP": "TLandrixGaebPhase", "tgVersion": "TLandrixGaebVersion",
                "tgGAEBVersDate": "TLandrixGaebEdition"}

RESERVED = set("""
and array as asm begin case class const constructor destructor dispinterface div do downto
else end except exports file finalization finally for function goto if implementation in
inherited initialization inline interface is label library mod nil not object of or out
packed procedure program property raise record repeat resourcestring set shl shr string then
threadvar to try type unit until uses var while with xor absolute abstract assembler automated
cdecl default dispid dynamic export external far forward index message near nodefault
overload override pascal private protected public published read readonly register
reintroduce resident safecall stdcall stored virtual write writeonly operator self result
specialize generic helper strict sealed final static reference implements experimental
deprecated platform on at
create free destroy classname classtype classinfo classparent instancesize inheritsfrom
methodaddress methodname fieldaddress afterconstruction beforedestruction dispatch
defaulthandler newinstance freeinstance cleanupinstance equals gethashcode tostring
length copy pos low high ord chr inc dec exit assigned trunc round abs include exclude
sizeof str val delete insert concat succ pred odd new dispose break continue halt
elementname present isempty ispresent clear children items count add
freeandnil hasvalue addvalue addnode getchildren fchildren haschildren
""".split())

# attribute names that get the suffix Attr in every class (decision 21.10.2026)
ATTR_SUFFIX_ALWAYS = {"class", "style", "type"}


def fail(msg):
    sys.stderr.write("gen-gaeb-model: " + msg + "\n")
    sys.exit(2)


def cap(name):
    return name[:1].upper() + name[1:]


def default_class_name(schema_name):
    """tgItem -> Item; tgCOInfo/COInit -> COInfoCOInit; tgAward/group set by caller."""
    parts = schema_name.split("/")
    base = parts[0][2:] if parts[0].startswith("tg") else parts[0]
    return cap(base) + "".join(cap(p.lstrip("@")) for p in parts[1:])


def default_member_name(kind, name, clash_names):
    """kind: e (element field), a (attribute), c (child helper)."""
    n = cap(name)
    if kind == "a":
        if name.lower() in ATTR_SUFFIX_ALWAYS or name.lower() in RESERVED or name.lower() in clash_names:
            return n + "Attr"
        return n
    if kind == "c":
        return n  # used as Add<Name> only
    if name.lower() in RESERVED:
        return n + "Element"
    return n


def sanitize_code(value):
    s = re.sub(r"[^A-Za-z0-9]+", "_", value).strip("_")
    return s or "Empty"


def enum_prefix(type_suffix, taken):
    """gx + capitals of the type name (YesNo -> gxyn); longer when taken."""
    caps = "".join(ch for ch in type_suffix if ch.isupper() or ch.isdigit()).lower()
    candidates = ["gx" + caps] if caps else []
    plain = re.sub(r"[^A-Za-z0-9]", "", type_suffix).lower()
    candidates += ["gx" + plain[:k] for k in range(3, len(plain) + 1)]
    for c in candidates:
        if c not in taken:
            return c
    fail("no enum prefix for %s" % type_suffix)


class Names(object):
    """The committed name table; records what is used, reports what is missing."""

    def __init__(self, data, update):
        self.data = data
        self.update = update
        self.used = {"classes": set(), "members": set(), "enums": set()}
        self.missing = []

    def cls(self, schema_name, default):
        self.used["classes"].add(schema_name)
        table = self.data.setdefault("classes", {})
        if schema_name not in table:
            if not self.update:
                self.missing.append("class " + schema_name)
            table[schema_name] = default
        return table[schema_name]

    def member(self, key, default):
        self.used["members"].add(key)
        table = self.data.setdefault("members", {})
        if key not in table:
            if not self.update:
                self.missing.append("member " + key)
            table[key] = default
        return table[key]

    def enum(self, schema_name, default_type, default_prefix, values):
        self.used["enums"].add(schema_name)
        table = self.data.setdefault("enums", {})
        entry = table.get(schema_name)
        if entry is None and default_prefix is None:
            taken = set(e["prefix"] for e in table.values())
            default_prefix = enum_prefix(default_type[len(CLASS_PREFIX):], taken)
        if entry is None:
            if not self.update:
                self.missing.append("enum " + schema_name)
            entry = {"type": default_type, "prefix": default_prefix, "values": {}}
            table[schema_name] = entry
        for v in values:
            if v not in entry["values"]:
                if not self.update:
                    self.missing.append("enum value %s %r" % (schema_name, v))
                entry["values"][v] = sanitize_code(v)
        stale = [v for v in entry["values"] if v not in values]
        for v in stale:
            if self.update:
                del entry["values"][v]
            else:
                self.missing.append("unused enum value %s %r" % (schema_name, v))
        return entry

    def prune(self):
        for section in ("classes", "members", "enums"):
            table = self.data.get(section, {})
            for k in list(table):
                if k not in self.used[section]:
                    if self.update:
                        del table[k]
                    else:
                        self.missing.append("unused %s entry %s" % (section, k))


class Model(object):
    def __init__(self, merged, names):
        self.classes = merged["classes"]
        self.contexts = merged["contexts"]
        self.names = names
        self.emit = {}       # schema type -> class info for emitted classes
        self.enums = []      # enum infos
        self.idents = {}     # lower-case identifier -> origin (global uniqueness)

    def ident(self, name, origin):
        key = name.lower()
        if key in self.idents and self.idents[key] != origin:
            fail("identifier %s used for %s and %s" % (name, self.idents[key], origin))
        self.idents[key] = origin
        return name

    def simple(self, tname):
        return tname.startswith("xs:") or self.classes[tname]["kind"] == "simple"

    def family(self, tname):
        if tname.startswith("xs:"):
            return {"xs:decimal": "decimaltext"}.get(tname, "text")
        return self.classes[tname]["family"]

    def value_type(self, tname, where):
        fam = self.family(tname)
        if fam == "decimal":
            return "TLandrixGaebDecimal"
        if fam == "decimaltext":
            return "TLandrixGaebDecimalText"
        if fam in ("text", "integer", "date", "time", "gYearMonth", "float", "boolean"):
            return "TLandrixGaebString"
        fail("%s: unsupported value family %s" % (where, fam))

    def build(self):
        complex_types = [n for n, c in sorted(self.classes.items())
                         if c["kind"] in ("complex", "simplecontent", "group") and c["published"]]
        # class names
        for n in complex_types:
            c = self.classes[n]
            if c["kind"] == "group":
                continue
            suffix = self.names.cls(n, default_class_name(n))
            self.emit[n] = {"schema": n, "name": CLASS_PREFIX + suffix, "kind": c["kind"]}
        for n in complex_types:
            c = self.classes[n]
            if c["kind"] != "group":
                continue
            owner = c["owner"]
            first = [f for f in c["fields"] if not f["name"].startswith("#") and f["published"]]
            first_child = [ch for ch in c.get("children", []) if ch["published"]]
            hint = (first[0]["name"] if first and c["fields"][0]["name"] == first[0]["name"]
                    else first_child[0]["name"] if first_child else first[0]["name"])
            field = self.names.member(owner + "|#group", hint + "Group")
            suffix = self.names.cls(n, default_class_name(owner) + field)
            self.emit[n] = {"schema": n, "name": CLASS_PREFIX + suffix, "kind": "group",
                            "group_field": field}
        for info in self.emit.values():
            self.ident(info["name"], "class " + info["schema"])
        for n in sorted(self.emit):
            self.build_members(self.emit[n])
        for info in self.emit.values():
            for m in info["members"]:
                if m["kind"] == "list":
                    self.ident(m["cls"] + "List", "list of " + m["type"])
        self.build_enums()

    def build_members(self, info):
        n = info["schema"]
        c = self.classes[n]
        elements = set(f["name"].lower() for f in c.get("fields", []) if not f["name"].startswith("#"))
        attrs = []
        for a in c.get("attributes", []):
            if not a["published"]:
                continue
            pname = self.names.member(n + "|a:" + a["name"], default_member_name("a", a["name"], elements))
            attrs.append({"schema": a["name"], "name": pname, "type": a["type"],
                          "vtype": self.value_type(a["type"], n + "/@" + a["name"]),
                          "use": a["use"]})
        members = []
        for f in c.get("fields", []):
            if f["name"] == "#children":
                kids = []
                for ch in c.get("children", []):
                    if not ch["published"]:
                        continue
                    pname = self.names.member(n + "|c:" + ch["name"], default_member_name("c", ch["name"], set()))
                    if self.simple(ch["type"]):
                        if self.value_type(ch["type"], n + "/" + ch["name"]) != "TLandrixGaebString":
                            fail("%s: child %s with a non-text value" % (n, ch["name"]))
                        kids.append({"schema": ch["name"], "name": pname, "simple": True, "type": ch["type"]})
                    else:
                        kids.append({"schema": ch["name"], "name": pname, "simple": False,
                                     "type": ch["type"], "cls": self.emit[ch["type"]]["name"]})
                members.append({"kind": "children", "children": kids})
                continue
            if not f.get("published"):
                continue
            if f["name"] == "#group":
                g = self.emit[f["type"]]
                members.append({"kind": "list", "schema": "#group", "name": g["group_field"],
                                "cls": g["name"], "type": f["type"]})
                continue
            pname = self.names.member(n + "|e:" + f["name"], default_member_name("e", f["name"], set()))
            if self.simple(f["type"]):
                if f["list"]:
                    fail("%s: repeated simple element %s outside an ordered region" % (n, f["name"]))
                members.append({"kind": "value", "schema": f["name"], "name": pname, "type": f["type"],
                                "vtype": self.value_type(f["type"], n + "/" + f["name"])})
            else:
                kind = "list" if f["list"] else "object"
                members.append({"kind": kind, "schema": f["name"], "name": pname, "type": f["type"],
                                "cls": self.emit[f["type"]]["name"]})
        if c["kind"] == "simplecontent":
            if n == "tgImage":
                members.insert(0, {"kind": "base64", "schema": "", "name": "Base64", "type": "tgString"})
            else:
                st = sorted(c["simple"])[0]
                members.insert(0, {"kind": "value", "schema": "", "name": "Value", "type": st,
                                   "vtype": self.value_type(st, n + " content")})
        local = dict((x, True) for x in ("present", "elementname", "isempty", "ispresent", "clear",
                                          "destroy", "create", "free", "fchildren", "getchildren"))
        for m in members + attrs:
            if m.get("kind") != "children" and m["name"].lower() in RESERVED and m["name"] not in ("Value", "Base64"):
                fail("%s: member name %s is reserved" % (n, m["name"]))
            if m.get("kind") in ("object", "list"):
                for x in ("F" + m["name"], "Get" + m["name"]):
                    if x.lower() in local:
                        fail("%s: member name %s twice" % (n, x))
                    local[x.lower()] = True
            kind = m.get("kind", "attribute")
            names = [m["name"]] if kind != "children" else ["Children"] + ["Add" + k["name"] for k in m["children"]]
            if kind in ("object", "list"):
                names.append("Has" + m["name"])
            if kind == "children":
                names.append("HasChildren")
            for x in names:
                if x.lower() in local:
                    fail("%s: member name %s twice" % (n, x))
                local[x.lower()] = True
        info["members"] = members
        info["attributes"] = attrs

    def build_enums(self):
        referenced = set()
        for info in self.emit.values():
            for m in info["members"]:
                if m["kind"] == "value":
                    referenced.add(m["type"])
                if m["kind"] == "children":
                    referenced.update(k["type"] for k in m["children"] if k["simple"])
            referenced.update(a["type"] for a in info["attributes"])
        for n in sorted(referenced):
            if n.startswith("xs:") or n in MAPPED_ENUMS:
                continue
            c = self.classes[n]
            values = [e["value"] for e in c.get("enumeration", []) if e["published"]]
            if not values:
                continue
            suffix = default_class_name(n)
            entry = self.names.enum(n, CLASS_PREFIX + suffix, None, values)
            members = [entry["prefix"] + "None", entry["prefix"] + "Unrecognized"]
            members += [entry["prefix"] + entry["values"][v] for v in values]
            seen = set()
            for m in members:
                if m.lower() in seen:
                    fail("enum %s: member %s twice" % (n, m))
                seen.add(m.lower())
                self.ident(m, "enum member of " + n)
            self.ident(entry["type"], "enum " + n)
            self.enums.append({"schema": n, "type": entry["type"], "members": members,
                               "values": values, "open": c.get("open", False)})


# ---- Pascal output ----

HEADER = """{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ GENERATED by tools/schema/gen-gaeb-model.py from the GAEB DA XML schemas
  3.2 and 3.3 (tools/schema/manifest.json) - do not edit; change the
  generator and run it again.
  DE: ERZEUGT von tools/schema/gen-gaeb-model.py aus den GAEB-DA-XML-Schemas
  3.2 und 3.3 (tools/schema/manifest.json) - nicht von Hand aendern; den
  Generator aendern und erneut ausfuehren. }
"""


def wrap_comment(lines_en, lines_de, indent):
    """{ English. DE: German. } wrapped at 100 columns."""
    out = []
    words = ("{ " + lines_en + " DE: " + lines_de + " }").split(" ")
    line = indent
    for w in words:
        if len(line) + len(w) + 1 > 100 and line.strip():
            out.append(line.rstrip())
            line = indent + "  "
        line += w + " "
    out.append(line.rstrip())
    return out


def value_clear(m):
    if m["vtype"] == "TLandrixGaebString":
        return "%s := '';" % m["name"]
    return "%s.Clear;" % m["name"]


def value_empty(m):
    if m["vtype"] == "TLandrixGaebString":
        return "(%s = '')" % m["name"]
    return "not %s.HasValue" % m["name"]


def type_label(tname):
    return tname


def gen_model(model):
    out = []
    w = out.append
    w(HEADER)
    w("""{ GAEB DA XML syntax model: the document as object tree, one class per
  schema type with element content (plan 3.4, 7.1 to 7.4). Values are
  lexical text ('' = absent) except bounded decimals (TLandrixGaebDecimal)
  and unbounded decimals (TLandrixGaebDecimalText). Single complex children
  are created on first access and never nil; HasX tells whether a child is
  present without creating it. Repeated choices keep their elements in
  Children in document order. Presence: see LandrixGaebXmlBase. Elements
  that exist only in the 3.4 beta are not part of the model.

  DE: GAEB-DA-XML-Syntaxmodell: das Dokument als Objektbaum, eine Klasse je
  Schematyp mit Elementinhalt (Plan 3.4, 7.1 bis 7.4). Werte sind
  lexikalischer Text ('' = nicht vorhanden), ausser begrenzten Dezimalen
  (TLandrixGaebDecimal) und unbegrenzten Dezimalen
  (TLandrixGaebDecimalText). Einzelne komplexe Kinder werden beim ersten
  Zugriff angelegt und sind nie nil; HasX sagt, ob ein Kind vorhanden ist,
  ohne es anzulegen. Wiederholte Choices halten ihre Elemente in Children
  in Dokumentreihenfolge. Vorhandensein: siehe LandrixGaebXmlBase. Elemente,
  die es nur in der Beta 3.4 gibt, sind nicht Teil des Modells. }

{ API: internal. May change in any release before 1.0.
  DE: API: intern. Kann sich vor Version 1.0 in jeder Version aendern. }

unit LandrixGaebXmlModel;

{$I LandrixGaeb.inc}

interface

uses
  SysUtils,
  Classes,
  Contnrs,
  LandrixXmlBase,
  LandrixGaebTypes,
  LandrixGaebXmlBase;

type""")
    infos = [model.emit[n] for n in sorted(model.emit, key=lambda k: model.emit[k]["name"].lower())]
    for info in infos:
        w("  %s = class;" % info["name"])
    w("")
    listed = sorted(set(m["cls"] for info in infos for m in info["members"] if m["kind"] == "list"),
                    key=str.lower)
    for cls in listed:
        w("\n".join(wrap_comment("List of %s (owns its items)." % cls,
                                 "Liste von %s (besitzt ihre Eintraege)." % cls, "  ")))
        w("  %sList = class(TObjectList)" % cls)
        w("  protected")
        w("    function GetItem(Index: TLandrixGaebListIndex): %s;" % cls)
        w("  public")
        w("    { Appends a new item and returns it. DE: Haengt einen neuen Eintrag an")
        w("      und liefert ihn. }")
        w("    function Add: %s;" % cls)
        w("    { True if no item is present. DE: True, wenn kein Eintrag vorhanden ist. }")
        w("    function IsEmpty: Boolean;")
        w("    { The items. DE: Die Eintraege. }")
        w("    property Items[Index: TLandrixGaebListIndex]: %s read GetItem; default;" % cls)
        w("  end;")
        w("")
    for info in infos:
        gen_class_decl(info, w)
    w("implementation")
    w("")
    for cls in listed:
        w("{ %sList }" % cls)
        w("")
        w("function %sList.GetItem(Index: TLandrixGaebListIndex): %s;" % (cls, cls))
        w("begin")
        w("  Result := %s(inherited Items[Index]);" % cls)
        w("end;")
        w("")
        w("function %sList.Add: %s;" % (cls, cls))
        w("begin")
        w("  Result := %s.Create;" % cls)
        w("  inherited Add(Result);")
        w("end;")
        w("")
        w("function %sList.IsEmpty: Boolean;" % cls)
        w("var")
        w("  I: TLandrixGaebListIndex;")
        w("begin")
        w("  Result := False;")
        w("  for I := 0 to Count - 1 do")
        w("    if Items[I].IsPresent then")
        w("      Exit;")
        w("  Result := True;")
        w("end;")
        w("")
    for info in infos:
        gen_class_impl(info, w)
    w("end.")
    return "\r\n".join("\n".join(out).split("\n")) + "\r\n"


def describe(info):
    s = info["schema"]
    if info["kind"] == "group":
        return ("Repeated group of %s (a mandatory member and the elements that belong to it)." % s.split("/")[0],
                "Wiederholte Gruppe von %s (ein Pflichtglied und die zugehoerigen Elemente)." % s.split("/")[0])
    if info["kind"] == "simplecontent":
        return ("Schema type %s: text content with attributes." % s,
                "Schematyp %s: Textinhalt mit Attributen." % s)
    return ("Schema type %s." % s, "Schematyp %s." % s)


def gen_class_decl(info, w):
    en, de = describe(info)
    w("\n".join(wrap_comment(en, de, "  ")))
    w("  %s = class(TLandrixGaebXmlNode)" % info["name"])
    objs = [m for m in info["members"] if m["kind"] in ("object", "list")]
    kids = [m for m in info["members"] if m["kind"] == "children"]
    if objs or kids:
        w("  private")
        for m in objs:
            t = m["cls"] + ("List" if m["kind"] == "list" else "")
            w("    F%s: %s;" % (m["name"], t))
        if kids:
            w("    FChildren: TLandrixGaebXmlNodeList;")
        for m in objs:
            t = m["cls"] + ("List" if m["kind"] == "list" else "")
            w("    function Get%s: %s;" % (m["name"], t))
        if kids:
            w("    function GetChildren: TLandrixGaebXmlNodeList;")
    w("  public")
    for m in info["members"]:
        if m["kind"] == "value":
            if m["schema"]:
                en = "Element %s (%s)." % (m["schema"], m["type"])
                de = "Element %s (%s)." % (m["schema"], m["type"])
            else:
                en = "Text content (%s)." % m["type"]
                de = "Textinhalt (%s)." % m["type"]
            w("\n".join(wrap_comment(en, de, "    ")))
            w("    %s: %s;" % (m["name"], m["vtype"]))
        elif m["kind"] == "base64":
            w("\n".join(wrap_comment("Image data as Base64 text (UTF-8 bytes, never UTF-16).",
                                     "Bilddaten als Base64-Text (UTF-8-Bytes, nie UTF-16).", "    ")))
            w("    Base64: TLandrixXmlUtf8;")
    for a in info["attributes"]:
        req = ", required" if a["use"] == "required" else ""
        req_de = ", Pflicht" if a["use"] == "required" else ""
        w("\n".join(wrap_comment("Attribute %s (%s%s)." % (a["schema"], a["type"], req),
                                 "Attribut %s (%s%s)." % (a["schema"], a["type"], req_de), "    ")))
        w("    %s: %s;" % (a["name"], a["vtype"]))
    w("    destructor Destroy; override;")
    w("    function IsEmpty: Boolean; override;")
    w("    procedure Clear; override;")
    for m in objs:
        t = m["cls"] + ("List" if m["kind"] == "list" else "")
        if m["schema"] == "#group":
            en = "Repeated groups (%s)." % m["cls"]
            de = "Wiederholte Gruppen (%s)." % m["cls"]
        elif m["kind"] == "list":
            en = "Element %s (%s), repeated; created on first access." % (m["schema"], m["type"])
            de = "Element %s (%s), wiederholt; beim ersten Zugriff angelegt." % (m["schema"], m["type"])
        else:
            en = "Element %s (%s); created on first access, never nil." % (m["schema"], m["type"])
            de = "Element %s (%s); beim ersten Zugriff angelegt, nie nil." % (m["schema"], m["type"])
        w("\n".join(wrap_comment(en, de, "    ")))
        w("    property %s: %s read Get%s;" % (m["name"], t, m["name"]))
        w("\n".join(wrap_comment("True if %s is present; creates nothing." % m["name"],
                                 "True, wenn %s vorhanden ist; legt nichts an." % m["name"], "    ")))
        w("    function Has%s: Boolean;" % m["name"])
    for k in kids:
        names = ", ".join(c["schema"] for c in k["children"])
        w("\n".join(wrap_comment("Ordered child elements (%s) in document order; created on first access." % names,
                                 "Geordnete Kindelemente (%s) in Dokumentreihenfolge; beim ersten Zugriff angelegt." % names,
                                 "    ")))
        w("    property Children: TLandrixGaebXmlNodeList read GetChildren;")
        w("    { True if a child is present; creates nothing. DE: True, wenn ein Kind")
        w("      vorhanden ist; legt nichts an. }")
        w("    function HasChildren: Boolean;")
        for c in k["children"]:
            if c["simple"]:
                w("\n".join(wrap_comment("Appends element %s (%s) to Children." % (c["schema"], c["type"]),
                                         "Haengt Element %s (%s) an Children an." % (c["schema"], c["type"]), "    ")))
                w("    function Add%s(const AValue: TLandrixGaebString): TLandrixGaebXmlValueNode;" % c["name"])
            else:
                w("\n".join(wrap_comment("Appends element %s (%s) to Children." % (c["schema"], c["type"]),
                                         "Haengt Element %s (%s) an Children an." % (c["schema"], c["type"]), "    ")))
                w("    function Add%s: %s;" % (c["name"], c["cls"]))
    w("  end;")
    w("")


def gen_class_impl(info, w):
    name = info["name"]
    objs = [m for m in info["members"] if m["kind"] in ("object", "list")]
    kids = [m for m in info["members"] if m["kind"] == "children"]
    values = [m for m in info["members"] if m["kind"] == "value"] + info["attributes"]
    b64 = [m for m in info["members"] if m["kind"] == "base64"]
    w("{ %s }" % name)
    w("")
    for m in objs:
        t = m["cls"] + ("List" if m["kind"] == "list" else "")
        w("function %s.Get%s: %s;" % (name, m["name"], t))
        w("begin")
        w("  if F%s = nil then" % m["name"])
        if m["kind"] == "object":
            w("  begin")
            w("    F%s := %s.Create;" % (m["name"], t))
            w("    F%s.ElementName := '%s';" % (m["name"], m["schema"]))
            w("  end;")
        else:
            w("    F%s := %s.Create;" % (m["name"], t))
        w("  Result := F%s;" % m["name"])
        w("end;")
        w("")
        w("function %s.Has%s: Boolean;" % (name, m["name"]))
        w("begin")
        if m["kind"] == "object":
            w("  Result := (F%s <> nil) and F%s.IsPresent;" % (m["name"], m["name"]))
        else:
            w("  Result := (F%s <> nil) and not F%s.IsEmpty;" % (m["name"], m["name"]))
        w("end;")
        w("")
    for k in kids:
        w("function %s.GetChildren: TLandrixGaebXmlNodeList;" % name)
        w("begin")
        w("  if FChildren = nil then")
        w("    FChildren := TLandrixGaebXmlNodeList.Create;")
        w("  Result := FChildren;")
        w("end;")
        w("")
        w("function %s.HasChildren: Boolean;" % name)
        w("begin")
        w("  Result := (FChildren <> nil) and not FChildren.IsEmpty;")
        w("end;")
        w("")
        for c in k["children"]:
            if c["simple"]:
                w("function %s.Add%s(const AValue: TLandrixGaebString): TLandrixGaebXmlValueNode;" % (name, c["name"]))
                w("begin")
                w("  Result := GetChildren.AddValue('%s', AValue);" % c["schema"])
                w("end;")
            else:
                w("function %s.Add%s: %s;" % (name, c["name"], c["cls"]))
                w("begin")
                w("  Result := %s.Create;" % c["cls"])
                w("  Result.ElementName := '%s';" % c["schema"])
                w("  GetChildren.AddNode(Result);")
                w("end;")
            w("")
    w("destructor %s.Destroy;" % name)
    w("begin")
    for m in objs:
        w("  F%s.Free;" % m["name"])
    if kids:
        w("  FChildren.Free;")
    w("  inherited Destroy;")
    w("end;")
    w("")
    w("function %s.IsEmpty: Boolean;" % name)
    w("begin")
    conds = ["inherited IsEmpty"] + [value_empty(m) for m in values]
    conds += ["(Base64 = '')" for _ in b64]
    conds += ["not Has%s" % m["name"] for m in objs]
    conds += ["not HasChildren" for _ in kids]
    line = "  Result := " + conds[0]
    for cnd in conds[1:]:
        w(line + " and")
        line = "    " + cnd
    w(line + ";")
    w("end;")
    w("")
    w("procedure %s.Clear;" % name)
    w("begin")
    w("  inherited Clear;")
    for m in values:
        w("  " + value_clear(m))
    for _ in b64:
        w("  Base64 := '';")
    for m in objs:
        w("  FreeAndNil(F%s);" % m["name"])
    if kids:
        w("  FreeAndNil(FChildren);")
    w("end;")
    w("")


def gen_codes(model):
    out = []
    w = out.append
    w(HEADER)
    w("""{ Codes of the enumerated GAEB DA XML simple types as Pascal enumerations,
  with conversion from and to the code text of the syntax model. The first
  member of every enumeration means "no value" (''), the second a code the
  schema does not list (kept as text in the model). Member names are
  stable; ordinal values are not part of the API. The exchange phase (DP),
  the version and the schema edition use TLandrixGaebPhase,
  TLandrixGaebVersion and TLandrixGaebEdition of LandrixGaebTypes.

  DE: Codes der aufgezaehlten einfachen GAEB-DA-XML-Typen als
  Pascal-Aufzaehlungen mit Umwandlung von und zum Codetext des
  Syntaxmodells. Das erste Element jeder Aufzaehlung bedeutet "kein Wert"
  (''), das zweite einen Code, den das Schema nicht kennt (im Modell als
  Text erhalten). Die Elementnamen sind stabil, die Ordinalwerte gehoeren
  nicht zur API. Austauschphase (DP), Version und Schema-Ausgabe benutzen
  TLandrixGaebPhase, TLandrixGaebVersion und TLandrixGaebEdition aus
  LandrixGaebTypes. }

{ API: internal. May change in any release before 1.0.
  DE: API: intern. Kann sich vor Version 1.0 in jeder Version aendern. }

unit LandrixGaebXmlCodes;

{$I LandrixGaeb.inc}

interface

uses
  LandrixXmlBase,
  LandrixGaebTypes;

type""")
    for e in model.enums:
        note = " The schema also allows other values (open list)." if e["open"] else ""
        note_de = " Das Schema erlaubt auch andere Werte (offene Liste)." if e["open"] else ""
        w("\n".join(wrap_comment("Codes of %s.%s" % (e["schema"], note),
                                 "Codes von %s.%s" % (e["schema"], note_de), "  ")))
        line = "  %s = (" % e["type"]
        parts = []
        for i, m in enumerate(e["members"]):
            parts.append(m + ("," if i < len(e["members"]) - 1 else ");"))
        cur = line
        for p in parts:
            if len(cur) + len(p) + 1 > 100:
                w(cur.rstrip())
                cur = "    "
            cur += p + " "
        w(cur.rstrip())
        w("")
    for e in model.enums:
        t = e["type"]
        short = t[len(CLASS_PREFIX):]
        w("\n".join(wrap_comment("Enumeration value of a %s code ('' -> first member, unknown code -> second)." % e["schema"],
                                 "Aufzaehlungswert eines %s-Codes ('' -> erstes Element, unbekannter Code -> zweites)." % e["schema"],
                                 "")))
        w("function LandrixGaebXml%sFromText(const AText: TLandrixGaebString): %s;" % (short, t))
        w("\n".join(wrap_comment("Code text of a %s value ('' for the first two members)." % e["schema"],
                                 "Codetext eines %s-Werts ('' fuer die ersten beiden Elemente)." % e["schema"], "")))
        w("function LandrixGaebXml%sToText(AValue: %s): TLandrixGaebString;" % (short, t))
        w("")
    w("implementation")
    w("")
    w("""{ Index of AText in ACodes (the first two entries are skipped), 0 for '',
  1 for an unknown code. }
function CodeIndex(const AText: TLandrixGaebString; const ACodes: array of TLandrixXmlUtf8): Integer;
var
  U: TLandrixXmlUtf8;
  I: Integer;
begin
  Result := 0;
  if AText = '' then
    Exit;
  U := LandrixXmlWideToUtf8(AText);
  for I := 2 to Integer(High(ACodes)) do
    if ACodes[I] = U then
    begin
      Result := I;
      Exit;
    end;
  Result := 1;
end;
""")
    w("const")
    for e in model.enums:
        t = e["type"]
        short = t[len(CLASS_PREFIX):]
        codes = ["''", "''"] + ["'%s'" % v.replace("'", "''") for v in e["values"]]
        line = "  %sCodes: array[%s] of TLandrixXmlUtf8 = (" % (short, t)
        cur = line
        for i, cde in enumerate(codes):
            part = cde + ("," if i < len(codes) - 1 else ");")
            if len(cur) + len(part) + 1 > 100:
                w(cur.rstrip())
                cur = "    "
            cur += part + " "
        w(cur.rstrip())
    w("")
    for e in model.enums:
        t = e["type"]
        short = t[len(CLASS_PREFIX):]
        w("function LandrixGaebXml%sFromText(const AText: TLandrixGaebString): %s;" % (short, t))
        w("begin")
        w("  Result := %s(CodeIndex(AText, %sCodes));" % (t, short))
        w("end;")
        w("")
        w("function LandrixGaebXml%sToText(AValue: %s): TLandrixGaebString;" % (short, t))
        w("begin")
        w("  Result := LandrixXmlUtf8ToWide(%sCodes[AValue]);" % short)
        w("end;")
        w("")
    w("end.")
    return "\r\n".join("\n".join(out).split("\n")) + "\r\n"


# ---- reader ----

READER_UNIT = os.path.join(ROOT, "source", "LandrixGaebXmlReader.pas")


def proc_name(info):
    return "Read" + info["name"][len(CLASS_PREFIX):]


def dispatch_entries(model, info):
    """(index, member, group) for every element the class reads directly;
    members of a group come with the group's index and the group info."""
    entries = []
    index = 0
    for m in info["members"]:
        if m["kind"] in ("base64",) or (m["kind"] == "value" and not m["schema"]):
            continue
        if m["kind"] == "children":
            for k in m["children"]:
                entries.append((index, {"kind": "child", "child": k}, None))
        elif m["kind"] == "list" and m["schema"] == "#group":
            g = model.emit[m["type"]]
            for gi, gm, _ in dispatch_entries(model, g):
                entries.append((index, gm, {"field": m["name"], "index": gi, "info": g}))
        else:
            entries.append((index, m, None))
        index += 1
    return entries


def element_of(m):
    return m["child"]["schema"] if m["kind"] == "child" else m["schema"]


def single(m):
    return m["kind"] in ("value", "object")


def have_expr(m, target):
    """Pascal expression: the single member m of target is already set."""
    if m["kind"] == "object":
        return "%s.Has%s" % (target, m["name"])
    if m["kind"] == "value":
        if m["vtype"] == "TLandrixGaebString":
            return "(%s.%s <> '')" % (target, m["name"])
        return "%s.%s.HasValue" % (target, m["name"])
    return "False"


def read_member(m, target, ind):
    """Statements reading member m into the object expression target."""
    if m["kind"] == "child":
        k = m["child"]
        if k["simple"]:
            return [ind + "%s.Add%s(C.ElementText).Present := True;" % (target, k["name"])]
        return [ind + "%s(C, %s.Add%s);" % ("Read" + k["cls"][len(CLASS_PREFIX):], target, k["name"])]
    if m["kind"] == "value":
        if m["vtype"] == "TLandrixGaebDecimal":
            return [ind + "C.ElementDecimal(%s.%s);" % (target, m["name"])]
        if m["vtype"] == "TLandrixGaebDecimalText":
            return [ind + "C.ElementDecimalText(%s.%s);" % (target, m["name"])]
        return [ind + "%s.%s := C.ElementText;" % (target, m["name"]),
                ind + "if %s.%s = '' then" % (target, m["name"]),
                ind + "  %s.MarkEmpty('%s');" % (target, m["schema"])]
    reader = "Read" + m["cls"][len(CLASS_PREFIX):]
    if m["kind"] == "object":
        return [ind + "%s(C, %s.%s);" % (reader, target, m["name"])]
    return [ind + "%s(C, %s.%s.Add);" % (reader, target, m["name"])]


def gen_read_proc(model, info, w):
    entries = dispatch_entries(model, info)
    groups = {}
    for _, _, g in entries:
        if g is not None:
            groups[g["field"]] = g["info"]
    has_children = any(m["kind"] == "children" for m in info["members"])
    content = [m for m in info["members"] if m["kind"] == "base64" or (m["kind"] == "value" and not m["schema"])]
    w("procedure %s(C: TLandrixGaebXmlReadContext; O: %s);" % (proc_name(info), info["name"]))
    w("var")
    if content:
        w("  I: Integer;")
    elif entries:
        w("  I, D, Last: Integer;")
    else:
        w("  I, D: Integer;")
    for field, g in sorted(groups.items()):
        w("  G%s: %s;" % (field, g["name"]))
        w("  G%sLast: Integer;" % field)
    w("begin")
    w("  C.Enter(O);")
    w("  for I := 0 to C.Reader.AttributeCount - 1 do")
    w("    if C.IsPlainAttribute(I) then")
    first = True
    for a in info["attributes"]:
        kw = "if" if first else "else if"
        first = False
        w("      %s C.AttributeIs(I, '%s') then" % (kw, a["schema"]))
        if a["vtype"] == "TLandrixGaebDecimal":
            w("        C.AttributeDecimal(I, O.%s)" % a["name"])
        elif a["vtype"] == "TLandrixGaebDecimalText":
            w("        C.AttributeDecimalText(I, O.%s)" % a["name"])
        else:
            w("      begin")
            w("        O.%s := C.AttributeText(I);" % a["name"])
            w("        if O.%s = '' then" % a["name"])
            w("          O.MarkEmpty('@%s');" % a["schema"])
            w("      end")
    w("      %sC.UnknownAttribute(I);" % ("" if first else "else "))
    if content:
        m = content[0]
        if m["kind"] == "base64":
            w("  O.Base64 := C.ContentTextUtf8;")
        elif m["vtype"] == "TLandrixGaebDecimal":
            w("  C.ContentDecimal(O.Value);")
        elif m["vtype"] == "TLandrixGaebDecimalText":
            w("  C.ContentDecimalText(O.Value);")
        else:
            w("  O.Value := C.ContentText;")
        w("end;")
        w("")
        return
    w("  D := C.Reader.Depth;")
    if entries:
        w("  Last := -1;")
    for field in sorted(groups):
        w("  G%s := nil;" % field)
        w("  G%sLast := -1;" % field)
    w("  while C.Next(D) do")
    w("    case C.Reader.TokenType of")
    w("      xttStartElement:")
    w("        if C.IsGaeb then")
    first = True
    for index, m, g in entries:
        kw = "if" if first else "else if"
        first = False
        w("          %s C.NameIs('%s') then" % (kw, element_of(m)))
        w("          begin")
        if g is None and single(m):
            w("            if C.Order(Last, %d, True, %s) then" % (index, have_expr(m, "O")))
        else:
            w("            if C.Order(Last, %d, False, False) then" % index)
        if g is None:
            w("            begin")
            for line in read_member(m, "O", "              "):
                w(line)
            w("            end;")
        else:
            f = g["field"]
            w("            begin")
            w("              if (G%s = nil) or C.NewGroup(G%sLast, %d, %s) then" % (f, f, g["index"],
                                                                                  "True" if single(m) else "False"))
            w("              begin")
            w("                G%s := O.%s.Add;" % (f, f))
            w("                G%s.Present := True;" % f)
            w("                G%sLast := -1;" % f)
            w("              end;")
            w("              if C.Order(G%sLast, %d, %s, False) then" % (f, g["index"], "True" if single(m) else "False"))
            w("              begin")
            for line in read_member(m, "G" + f, "                "):
                w(line)
            w("              end;")
            w("            end;")
        w("          end")
    if first:
        w("          C.UnknownElement;")
    else:
        w("          else")
        w("            C.UnknownElement;")
    w("      xttText, xttCData:")
    w("        if not C.Reader.IsWhitespace then")
    w("          C.TextInElementContent(%s);" % ("O.Children" if has_children else "nil"))
    w("    else")
    w("      ;")
    w("    end;")
    w("end;")
    w("")


def gen_reader(model):
    out = []
    w = out.append
    w(HEADER)
    w("""{ GAEB DA XML reader: reads a document of a supported target (3.2, 3.3)
  into the syntax model (LandrixGaebXmlModel) with the pull reader of
  LandrixXml. The input is checked first (size limit, format, document type
  declaration, namespace, target; LandrixGaebDetect); what the reader does
  not accept raises ELandrixGaebError, XML that is not well-formed raises
  ELandrixXmlError with position. Everything else that does not fit the
  schema becomes a diagnostic (LandrixGaebXmlReadBase) and reading goes on.

  DE: GAEB-DA-XML-Leser: liest ein Dokument eines unterstuetzten Ziels
  (3.2, 3.3) mit dem Pull-Reader von LandrixXml in das Syntaxmodell
  (LandrixGaebXmlModel). Zuerst wird die Eingabe geprueft
  (Groessengrenze, Format, Dokumenttyp-Deklaration, Namespace, Ziel;
  LandrixGaebDetect); was der Leser nicht annimmt, loest ELandrixGaebError
  aus, nicht wohlgeformtes XML ELandrixXmlError mit Position. Alles andere,
  was nicht zum Schema passt, wird eine Meldung (LandrixGaebXmlReadBase),
  und das Lesen geht weiter. }

{ API: internal. May change in any release before 1.0.
  DE: API: intern. Kann sich vor Version 1.0 in jeder Version aendern. }

unit LandrixGaebXmlReader;

{$I LandrixGaeb.inc}

interface

uses
  SysUtils,
  Classes,
  LandrixXmlBase,
  LandrixXmlReader,
  LandrixGaebTypes,
  LandrixGaebDiagnostics,
  LandrixGaebDetect,
  LandrixGaebXmlBase,
  LandrixGaebXmlModel,
  LandrixGaebXmlReadBase;

{ Reads a GAEB DA XML document from a buffer that holds the whole input.
  Targets outside the schemas of the model raise ELandrixGaebError.
  ADiagnostics may be nil; ADetection returns format and target.
  DE: Liest ein GAEB-DA-XML-Dokument aus einem Puffer mit der ganzen
  Eingabe. Ziele ausserhalb der Schemas des Modells loesen
  ELandrixGaebError aus. ADiagnostics darf nil sein; ADetection liefert
  Format und Ziel. }
function LandrixGaebXmlReadBuffer(Buffer: Pointer; Size: Integer;
  ADiagnostics: TLandrixGaebDiagnostics; out ADetection: TLandrixGaebDetection): TLandrixGaebXmlGAEB;

{ Reads from a stream (current position to the end). AMaxSize <= 0 means
  LandrixGaebDefaultMaxSize; larger input raises ELandrixGaebError before
  anything is read.
  DE: Liest aus einem Stream (aktuelle Position bis zum Ende).
  AMaxSize <= 0 bedeutet LandrixGaebDefaultMaxSize; groessere Eingaben
  loesen ELandrixGaebError aus, bevor etwas gelesen wird. }
function LandrixGaebXmlReadStream(AStream: TStream; ADiagnostics: TLandrixGaebDiagnostics;
  AMaxSize: Int64; out ADetection: TLandrixGaebDetection): TLandrixGaebXmlGAEB;

{ Reads a file. DE: Liest eine Datei. }
function LandrixGaebXmlReadFile(const AFileName: string; ADiagnostics: TLandrixGaebDiagnostics;
  AMaxSize: Int64; out ADetection: TLandrixGaebDetection): TLandrixGaebXmlGAEB;

implementation
""")
    infos = [model.emit[n] for n in sorted(model.emit, key=lambda k: model.emit[k]["name"].lower())
             if model.emit[n]["kind"] != "group"]
    for info in infos:
        w("procedure %s(C: TLandrixGaebXmlReadContext; O: %s); forward;" % (proc_name(info), info["name"]))
    w("")
    for info in infos:
        gen_read_proc(model, info, w)
    root = model.emit["tgGAEB"]
    conds = []
    for ctx in model.contexts:
        if not ctx["publish"]:
            continue
        conds.append("((ATarget.Version = gv%s) and (ATarget.Edition = ge%s) and (ATarget.Phase = gp%s))" % (
            ctx["version"].replace(".", ""), ctx["edition"].replace("-", "_"), ctx["phase"].replace(".", "_")))
    w("{ True if the generated model was built from the schema of ATarget. }")
    w("function ModelCoversTarget(const ATarget: TLandrixGaebTarget): Boolean;")
    w("begin")
    w("  Result := " + (" or\n    ".join(conds)) + ";")
    w("end;")
    w("")
    w("""function RejectMessage(ADiagnostics: TLandrixGaebDiagnostics; AFirst: Integer): string;
var
  I: TLandrixGaebListIndex;
begin
  Result := 'input is not a readable GAEB DA XML document';
  for I := AFirst to ADiagnostics.Count - 1 do
    if ADiagnostics[I].Severity >= gsError then
    begin
      Result := Result + ': [' + ADiagnostics[I].RuleId + '] ' + ADiagnostics[I].Message;
      Exit;
    end;
end;

function LandrixGaebXmlReadBuffer(Buffer: Pointer; Size: Integer;
  ADiagnostics: TLandrixGaebDiagnostics; out ADetection: TLandrixGaebDetection): TLandrixGaebXmlGAEB;
var
  Diags: TLandrixGaebDiagnostics;
  First: Integer;
  Reader: TLandrixXmlReader;
  Context: TLandrixGaebXmlReadContext;
begin
  Diags := ADiagnostics;
  if Diags = nil then
    Diags := TLandrixGaebDiagnostics.Create;
  try
    First := Integer(Diags.Count);
    ADetection := LandrixGaebDetectBuffer(Buffer, Size, False, Diags);
    if not ADetection.Accepted or (ADetection.Format <> gfXml) then
      raise ELandrixGaebError.Create(RejectMessage(Diags, First));
    if not LandrixGaebTargetIsSupported(ADetection.Target, False) or
      not ModelCoversTarget(ADetection.Target) then
      raise ELandrixGaebError.Create('GAEB DA XML ' +
        LandrixXmlUtf8ToString(LandrixGaebVersionToText(ADetection.Target.Version)) + ' ' +
        LandrixXmlUtf8ToString(LandrixGaebEditionToText(ADetection.Target.Edition)) + ' DA' +
        LandrixXmlUtf8ToString(LandrixGaebPhaseToDP(ADetection.Target.Phase)) +
        ' is not supported for reading');
  finally
    if ADiagnostics = nil then
      Diags.Free;
  end;
  Reader := TLandrixXmlReader.Create;
  try
    Reader.LoadFromBuffer(PAnsiChar(Buffer)^, Size);
    Context := TLandrixGaebXmlReadContext.Create(Reader, ADetection.Namespace, ADiagnostics);
    try
      Result := %s.Create;
      try
        if Context.MoveToRoot then
          %s(Context, Result);
        while Reader.Read do
          ;
      except
        Result.Free;
        raise;
      end;
    finally
      Context.Free;
    end;
  finally
    Reader.Free;
  end;
end;

function LandrixGaebXmlReadStream(AStream: TStream; ADiagnostics: TLandrixGaebDiagnostics;
  AMaxSize: Int64; out ADetection: TLandrixGaebDetection): TLandrixGaebXmlGAEB;
var
  Remaining: Int64;
  Buffer: AnsiString;
  Count: Integer;
begin
  if AMaxSize <= 0 then
    AMaxSize := LandrixGaebDefaultMaxSize;
  if AMaxSize > MaxInt then
    AMaxSize := MaxInt;
  Remaining := AStream.Size - AStream.Position;
  if Remaining > AMaxSize then
    raise ELandrixGaebError.Create('input of ' + IntToStr(Remaining) +
      ' bytes exceeds the size limit of ' + IntToStr(AMaxSize) + ' bytes');
  Count := Integer(Remaining);
  Buffer := '';
  SetLength(Buffer, Count);
  if Count > 0 then
    AStream.ReadBuffer(Buffer[1], Count);
  Result := LandrixGaebXmlReadBuffer(Pointer(Buffer), Count, ADiagnostics, ADetection);
end;

function LandrixGaebXmlReadFile(const AFileName: string; ADiagnostics: TLandrixGaebDiagnostics;
  AMaxSize: Int64; out ADetection: TLandrixGaebDetection): TLandrixGaebXmlGAEB;
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    Result := LandrixGaebXmlReadStream(Stream, ADiagnostics, AMaxSize, ADetection);
  finally
    Stream.Free;
  end;
end;

end.""" % (root["name"], proc_name(root)))
    return "\r\n".join("\n".join(out).split("\n")) + "\r\n"


# ---- profiles and writer ----

PROFILES_UNIT = os.path.join(ROOT, "source", "LandrixGaebXmlProfiles.pas")
WRITER_UNIT = os.path.join(ROOT, "source", "LandrixGaebXmlWriter.pas")
SLOT_FORBIDDEN = -1
SLOT_VALUE = -2
TEXT_CHILDREN = {"p", "span", "br"}


def load_merge_module():
    import importlib.util
    spec = importlib.util.spec_from_file_location("merge_gaeb", os.path.join(HERE, "merge-gaeb.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def slot_layout(info):
    """Slots of a class in order: (kind, member or attribute or child)."""
    slots = []
    for m in info["members"]:
        if m["kind"] == "base64" or (m["kind"] == "value" and not m["schema"]):
            slots.append(("content", m))
    for a in info["attributes"]:
        slots.append(("attr", a))
    for m in info["members"]:
        if m["kind"] == "children":
            for k in m["children"]:
                slots.append(("child", k))
        elif m["kind"] in ("value", "object", "list") and m["schema"]:
            slots.append(("member", m))
    return slots


def fraction_of(types, tname):
    if tname.startswith("xs:"):
        return -1
    t = types[tname]
    if t["kind"] == "complex":
        return fraction_of(types, t["simple"]) if "simple" in t else -1
    if t["kind"] != "simple" or t["base"] != "xs:decimal":
        return -1
    fd = t["facets"].get("fractionDigits")
    return int(fd) if fd is not None else -1


class Profiles(object):
    def __init__(self, model):
        self.model = model
        self.merge = load_merge_module()
        self.contexts = []
        for ctx in model.contexts:
            if not ctx["publish"]:
                continue
            path = os.path.join(HERE, "out", ctx["id"] + ".json")
            self.contexts.append((ctx, json.load(io.open(path, encoding="utf-8"))))
        self.rows = {}        # (class schema, type, ctx id) -> offset
        self.slots = []       # (row, fraction, comment)
        self.roots = []       # (ctx, offset)
        self.layouts = dict((n, slot_layout(i)) for n, i in model.emit.items())

    def shape(self, types, tname, group):
        s = self.merge.shape_of(types[tname].get("particle"), tname)
        if group:
            if s.group is None:
                fail("%s has no group" % tname)
            return s.group[0]
        return s

    def build(self):
        for ctx, data in self.contexts:
            root = self.row("tgGAEB", data["root"]["type"], ctx["id"], data["types"])
            self.roots.append((ctx, root))

    def row(self, cls, tname, cid, types):
        key = (cls, tname, cid)
        if key in self.rows:
            return self.rows[key]
        info = self.model.emit[cls]
        layout = self.layouts[cls]
        offset = len(self.slots)
        self.rows[key] = offset
        self.slots.extend([None] * len(layout))
        t = types[tname]
        is_group = info["kind"] == "group"
        shape = None
        if t["kind"] == "complex" and "simple" not in t:
            shape = self.shape(types, tname, is_group)
        attrs = {} if is_group else dict((a["name"], a["type"]) for a in t["attributes"])
        for i, (kind, m) in enumerate(layout):
            where = "%s %s %s" % (cid, cls, kind)
            if kind == "content":
                self.slots[offset + i] = (SLOT_VALUE, fraction_of(types, tname), "content")
            elif kind == "attr":
                if m["schema"] in attrs:
                    self.slots[offset + i] = (SLOT_VALUE, fraction_of(types, attrs[m["schema"]]), "@" + m["schema"])
                else:
                    self.slots[offset + i] = (SLOT_FORBIDDEN, -1, "@" + m["schema"])
            elif kind == "child":
                etype = None
                if shape is not None:
                    if m["schema"] in shape.child:
                        etype = shape.child[m["schema"]]
                    elif m["schema"] in shape.field:
                        etype = shape.field[m["schema"]][0]
                self.slots[offset + i] = self.slot_for(m, etype, cid, types, m["schema"])
            else:
                if m["schema"] == "#group":
                    if shape is not None and shape.group is not None:
                        child = self.row(m["type"], tname, cid, types)
                        self.slots[offset + i] = (child, -1, "group")
                    else:
                        self.slots[offset + i] = (SLOT_FORBIDDEN, -1, "group")
                    continue
                etype = shape.field[m["schema"]][0] if shape is not None and m["schema"] in shape.field else None
                self.slots[offset + i] = self.slot_for(m, etype, cid, types, m["schema"])
        return offset

    def slot_for(self, m, etype, cid, types, name):
        if etype is None:
            return (SLOT_FORBIDDEN, -1, name)
        simple = etype.startswith("xs:") or types[etype]["kind"] in ("simple", "union")
        if m.get("simple") or m.get("kind") == "value":
            if not simple:
                fail("%s: %s is complex in %s" % (name, etype, cid))
            return (SLOT_VALUE, fraction_of(types, etype), name)
        if simple:
            fail("%s: %s is simple in %s" % (name, etype, cid))
        cls = m["type"]
        return (self.row(cls, etype, cid, types), -1, name)


def gen_profiles(model, prof):
    out = []
    w = out.append
    w(HEADER)
    w("""{ Profiles of the GAEB DA XML targets of the syntax model: for every
  target (version, edition, phase) and every class as it appears there, one
  row of slots, one slot per attribute, element or child element name of the
  class. A slot tells whether the target allows the member, where the row of
  a complex child starts and how many fraction digits a bounded decimal has.
  Used by the writer and the check.

  DE: Profile der GAEB-DA-XML-Ziele des Syntaxmodells: fuer jedes Ziel
  (Version, Ausgabe, Phase) und jede Klasse, wie sie dort vorkommt, eine
  Zeile von Slots, ein Slot je Attribut, Element oder Kindelementname der
  Klasse. Ein Slot sagt, ob das Ziel das Mitglied erlaubt, wo die Zeile
  eines komplexen Kinds beginnt und wie viele Nachkommastellen eine
  begrenzte Dezimalzahl hat. Benutzt von Schreiber und Pruefung. }

{ API: internal. May change in any release before 1.0.
  DE: API: intern. Kann sich vor Version 1.0 in jeder Version aendern. }

unit LandrixGaebXmlProfiles;

{$I LandrixGaeb.inc}

interface

uses
  LandrixGaebTypes;

const
  { Slot value: the member is not allowed in the target.
    DE: Slotwert: Das Mitglied ist im Ziel nicht erlaubt. }
  LandrixGaebXmlSlotForbidden = %d;
  { Slot value: allowed simple value (no row).
    DE: Slotwert: erlaubter einfacher Wert (keine Zeile). }
  LandrixGaebXmlSlotValue = %d;

type
  { One slot. Row: start of the child's row, or LandrixGaebXmlSlotForbidden,
    or LandrixGaebXmlSlotValue. Fraction: fraction digits of a bounded
    decimal, -1 otherwise.
    DE: Ein Slot. Row: Beginn der Zeile des Kinds oder
    LandrixGaebXmlSlotForbidden oder LandrixGaebXmlSlotValue. Fraction:
    Nachkommastellen einer begrenzten Dezimalzahl, sonst -1. }
  TLandrixGaebXmlSlot = record
    Row: Integer;
    Fraction: Integer;
  end;

const""" % (SLOT_FORBIDDEN, SLOT_VALUE))
    w("  { All slots of all targets. DE: Alle Slots aller Ziele. }")
    w("  LandrixGaebXmlSlots: array[0..%d] of TLandrixGaebXmlSlot = (" % (len(prof.slots) - 1))
    for i, (row, frac, comment) in enumerate(prof.slots):
        sep = "," if i < len(prof.slots) - 1 else ");"
        w("    (Row: %d; Fraction: %d)%s { %d %s }" % (row, frac, sep, i, comment))
    w("")
    w("""{ Start of the row of the root element for a target; -1 if the model has
  no profile for it.
  DE: Beginn der Zeile des Wurzelelements fuer ein Ziel; -1, wenn das
  Modell kein Profil dafuer hat. }
function LandrixGaebXmlTargetRow(const ATarget: TLandrixGaebTarget): Integer;

implementation

function LandrixGaebXmlTargetRow(const ATarget: TLandrixGaebTarget): Integer;
begin
  Result := -1;""")
    for ctx, offset in prof.roots:
        w("  if (ATarget.Version = gv%s) and (ATarget.Edition = ge%s) and (ATarget.Phase = gp%s) then" % (
            ctx["version"].replace(".", ""), ctx["edition"].replace("-", "_"), ctx["phase"].replace(".", "_")))
        w("    Result := %d;" % offset)
    w("end;")
    w("")
    w("end.")
    return "\r\n".join("\n".join(out).split("\n")) + "\r\n"


def write_proc(info):
    return "Write" + info["name"][len(CLASS_PREFIX):]


def is_mixed(info):
    for m in info["members"]:
        if m["kind"] == "children" and any(k["schema"] in TEXT_CHILDREN for k in m["children"]):
            return True
    return False


def value_write(m, slot, target, info):
    name = m["schema"]
    if info["schema"] == "tgGAEBInfo" and name in ("Version", "VersDate"):
        return ["  W.ValueText(ARow + %d, '%s', W.Target%s(%s.%s));" % (slot, name, name, target, m["name"])]
    if name == "DP" and m["type"] == "tgDP":
        return ["  W.ValueText(ARow + %d, 'DP', W.TargetDP(%s.%s));" % (slot, target, m["name"])]
    if m["vtype"] == "TLandrixGaebDecimal":
        return ["  if %s.%s.HasValue then" % (target, m["name"]),
                "    W.ValueDecimal(ARow + %d, '%s', %s.%s);" % (slot, name, target, m["name"])]
    if m["vtype"] == "TLandrixGaebDecimalText":
        return ["  if %s.%s.HasValue then" % (target, m["name"]),
                "    W.ValueDecimalText(ARow + %d, '%s', %s.%s);" % (slot, name, target, m["name"])]
    return ["  if %s.%s <> '' then" % (target, m["name"]),
            "    W.ValueText(ARow + %d, '%s', %s.%s)" % (slot, name, target, m["name"]),
            "  else if %s.IsMarkedEmpty('%s') then" % (target, name),
            "    W.ValueText(ARow + %d, '%s', '');" % (slot, name)]


def gen_write_proc(model, prof, info, w):
    layout = prof.layouts[info["schema"]]
    slot_of = {}
    for i, (kind, m) in enumerate(layout):
        slot_of[(kind, id(m))] = i
    is_group = info["kind"] == "group"
    is_root = info["schema"] == "tgGAEB"
    has_lists = any(m["kind"] in ("list", "children") for m in info["members"])
    has_children = any(m["kind"] == "children" for m in info["members"])
    if is_group:
        w("procedure %s(W: TLandrixGaebXmlWriteContext; O: %s; ARow: Integer);" % (write_proc(info), info["name"]))
    else:
        w("procedure %s(W: TLandrixGaebXmlWriteContext; O: %s; const AName: TLandrixXmlUtf8;" % (
            write_proc(info), info["name"]))
        w("  ARow: Integer);")
    if has_lists:
        w("var")
        w("  I: TLandrixGaebListIndex;")
        if has_children:
            w("  N: TLandrixGaebXmlNode;")
    w("begin")
    if not is_group:
        if is_root:
            w("  W.StartRoot(AName);")
        else:
            w("  W.StartElement(AName, %s);" % ("True" if is_mixed(info) else "False"))
    for a in info["attributes"]:
        slot = slot_of[("attr", id(a))]
        if a["vtype"] == "TLandrixGaebDecimal":
            w("  if O.%s.HasValue then" % a["name"])
            w("    W.AttrDecimal(ARow + %d, '%s', O.%s);" % (slot, a["schema"], a["name"]))
        elif a["vtype"] == "TLandrixGaebDecimalText":
            w("  if O.%s.HasValue then" % a["name"])
            w("    W.AttrDecimalText(ARow + %d, '%s', O.%s);" % (slot, a["schema"], a["name"]))
        else:
            w("  if O.%s <> '' then" % a["name"])
            w("    W.AttrText(ARow + %d, '%s', O.%s)" % (slot, a["schema"], a["name"]))
            w("  else if O.IsMarkedEmpty('@%s') then" % a["schema"])
            w("    W.AttrText(ARow + %d, '%s', '');" % (slot, a["schema"]))
    for m in info["members"]:
        if m["kind"] == "base64":
            w("  W.ContentUtf8(O.Base64);")
        elif m["kind"] == "value" and not m["schema"]:
            slot = slot_of[("content", id(m))]
            if m["vtype"] == "TLandrixGaebDecimal":
                w("  W.ContentDecimal(ARow + %d, O.Value);" % slot)
            elif m["vtype"] == "TLandrixGaebDecimalText":
                w("  W.ContentDecimalText(O.Value);")
            else:
                w("  W.ContentText(O.Value);")
        elif m["kind"] == "value":
            for line in value_write(m, slot_of[("member", id(m))], "O", info):
                w(line)
        elif m["kind"] == "object":
            slot = slot_of[("member", id(m))]
            w("  if O.Has%s and W.Allowed(ARow + %d, '%s', False) then" % (m["name"], slot, m["schema"]))
            w("    %s(W, O.%s, '%s', W.ChildRow(ARow + %d));" % (
                write_proc(model.emit[m["type"]]), m["name"], m["schema"], slot))
        elif m["kind"] == "list":
            slot = slot_of[("member", id(m))]
            target = model.emit[m["type"]]
            label = m["schema"] if m["schema"] != "#group" else m["name"]
            w("  if O.Has%s then" % m["name"])
            w("    for I := 0 to O.%s.Count - 1 do" % m["name"])
            w("      if O.%s[I].IsPresent and W.Allowed(ARow + %d, '%s', False) then" % (m["name"], slot, label))
            if m["schema"] == "#group":
                w("        %s(W, O.%s[I], W.ChildRow(ARow + %d));" % (write_proc(target), m["name"], slot))
            else:
                w("        %s(W, O.%s[I], '%s', W.ChildRow(ARow + %d));" % (
                    write_proc(target), m["name"], m["schema"], slot))
        elif m["kind"] == "children":
            w("  if O.HasChildren then")
            w("    for I := 0 to O.Children.Count - 1 do")
            w("    begin")
            w("      N := O.Children[I];")
            w("      if not N.IsPresent then")
            w("        Continue;")
            first = True
            for k in m["children"]:
                slot = slot_of[("child", id(k))]
                kw = "if" if first else "else if"
                first = False
                if k["simple"]:
                    w("      %s (N is TLandrixGaebXmlValueNode) and (N.ElementName = '%s') then" % (kw, k["schema"]))
                    w("        W.ValueText(ARow + %d, '%s', TLandrixGaebXmlValueNode(N).Value)" % (slot, k["schema"]))
                else:
                    w("      %s (N is %s) and (N.ElementName = '%s') then" % (kw, k["cls"], k["schema"]))
                    w("      begin")
                    w("        if W.Allowed(ARow + %d, '%s', False) then" % (slot, k["schema"]))
                    w("          %s(W, %s(N), '%s', W.ChildRow(ARow + %d));" % (
                        write_proc(model.emit[k["type"]]), k["cls"], k["schema"], slot))
                    w("      end")
            w("      else")
            w("        W.BadChild(N.ElementName);")
            w("    end;")
    if not is_group:
        w("  W.EndElement;")
    w("end;")
    w("")


def gen_writer(model, prof):
    out = []
    w = out.append
    w(HEADER)
    w("""{ GAEB DA XML writer: writes the syntax model (LandrixGaebXmlModel) for a
  target (version, edition, phase) with the streaming writer of LandrixXml.
  Elements are written in schema order and only if present; what the target
  does not allow is reported (LandrixGaebXmlWriteBase). Namespace, Version,
  VersDate and DP come from the target only. Mandatory elements, choices
  and value facets are checked by LandrixGaebCheck, not here. Nothing is
  written to the destination when the mode aborts.

  DE: GAEB-DA-XML-Schreiber: schreibt das Syntaxmodell
  (LandrixGaebXmlModel) fuer ein Ziel (Version, Ausgabe, Phase) mit dem
  Streaming-Writer von LandrixXml. Elemente werden in Schemareihenfolge und
  nur wenn vorhanden geschrieben; was das Ziel nicht erlaubt, wird gemeldet
  (LandrixGaebXmlWriteBase). Namespace, Version, VersDate und DP kommen
  allein aus dem Ziel. Pflichtelemente, Choices und Wertfacetten prueft
  LandrixGaebCheck, nicht dieser Schreiber. Bricht der Modus ab, wird am
  Ziel nichts geschrieben. }

{ API: internal. May change in any release before 1.0.
  DE: API: intern. Kann sich vor Version 1.0 in jeder Version aendern. }

unit LandrixGaebXmlWriter;

{$I LandrixGaeb.inc}

interface

uses
  SysUtils,
  Classes,
  LandrixXmlBase,
  LandrixXmlWriter,
  LandrixGaebTypes,
  LandrixGaebDiagnostics,
  LandrixGaebXmlBase,
  LandrixGaebXmlModel,
  LandrixGaebXmlProfiles,
  LandrixGaebXmlWriteBase;

{ The document as UTF-8 for ATarget. Raises ELandrixGaebError if the target
  is not supported for writing or if the mode aborts (see
  TLandrixGaebXmlWriteMode), ELandrixXmlError if a value holds characters
  XML cannot carry. ADiagnostics may be nil.
  DE: Das Dokument als UTF-8 fuer ATarget. Loest ELandrixGaebError aus, wenn
  das Ziel nicht geschrieben werden kann oder der Modus abbricht (siehe
  TLandrixGaebXmlWriteMode), ELandrixXmlError, wenn ein Wert Zeichen
  enthaelt, die XML nicht tragen kann. ADiagnostics darf nil sein. }
function LandrixGaebXmlWriteUtf8(ADocument: TLandrixGaebXmlGAEB; const ATarget: TLandrixGaebTarget;
  const AOptions: TLandrixGaebXmlWriteOptions; ADiagnostics: TLandrixGaebDiagnostics): TLandrixXmlUtf8;

{ Writes the document to a stream (at its position).
  DE: Schreibt das Dokument in einen Stream (an seiner Position). }
procedure LandrixGaebXmlWriteStream(ADocument: TLandrixGaebXmlGAEB; const ATarget: TLandrixGaebTarget;
  AStream: TStream; const AOptions: TLandrixGaebXmlWriteOptions; ADiagnostics: TLandrixGaebDiagnostics);

{ Writes the document to a file; the file is only created when writing
  succeeds.
  DE: Schreibt das Dokument in eine Datei; die Datei wird nur angelegt,
  wenn das Schreiben gelingt. }
procedure LandrixGaebXmlWriteFile(ADocument: TLandrixGaebXmlGAEB; const ATarget: TLandrixGaebTarget;
  const AFileName: string; const AOptions: TLandrixGaebXmlWriteOptions;
  ADiagnostics: TLandrixGaebDiagnostics);

implementation
""")
    infos = [model.emit[n] for n in sorted(model.emit, key=lambda k: model.emit[k]["name"].lower())]
    for info in infos:
        if info["kind"] == "group":
            w("procedure %s(W: TLandrixGaebXmlWriteContext; O: %s; ARow: Integer); forward;" % (
                write_proc(info), info["name"]))
        else:
            w("procedure %s(W: TLandrixGaebXmlWriteContext; O: %s; const AName: TLandrixXmlUtf8;" % (
                write_proc(info), info["name"]))
            w("  ARow: Integer); forward;")
    w("")
    for info in infos:
        gen_write_proc(model, prof, info, w)
    root = model.emit["tgGAEB"]
    w("""function LandrixGaebXmlWriteUtf8(ADocument: TLandrixGaebXmlGAEB; const ATarget: TLandrixGaebTarget;
  const AOptions: TLandrixGaebXmlWriteOptions; ADiagnostics: TLandrixGaebDiagnostics): TLandrixXmlUtf8;
var
  Row: Integer;
  Writer: TLandrixXmlWriter;
  Context: TLandrixGaebXmlWriteContext;
  Failed: Boolean;
begin
  Row := LandrixGaebXmlTargetRow(ATarget);
  if (Row < 0) or not LandrixGaebTargetIsSupported(ATarget, True) then
    raise ELandrixGaebError.Create('GAEB DA XML ' +
      LandrixXmlUtf8ToString(LandrixGaebVersionToText(ATarget.Version)) + ' ' +
      LandrixXmlUtf8ToString(LandrixGaebEditionToText(ATarget.Edition)) + ' DA' +
      LandrixXmlUtf8ToString(LandrixGaebPhaseToDP(ATarget.Phase)) +
      ' is not supported for writing');
  Writer := TLandrixXmlWriter.Create;
  try
    Writer.WriteBom := AOptions.WriteBom;
    Writer.Indent := AOptions.Indent;
    if AOptions.CrLf then
      Writer.LineBreak := xlbCRLF
    else
      Writer.LineBreak := xlbLF;
    Context := TLandrixGaebXmlWriteContext.Create(Writer, AOptions, ATarget, ADiagnostics);
    try
      %s(Context, ADocument, 'GAEB', Row);
      Writer.EndDocument;
      case AOptions.Mode of
        gwmStrict:
          Failed := (Context.Errors > 0) or (Context.Warnings > 0);
        gwmNormal:
          Failed := Context.Errors > 0;
      else
        Failed := False;
      end;
      if Failed then
        raise ELandrixGaebError.Create('document not written: ' + IntToStr(Context.Errors) +
          ' error(s), ' + IntToStr(Context.Warnings) + ' warning(s) (see diagnostics)');
    finally
      Context.Free;
    end;
    Result := Writer.AsUtf8;
  finally
    Writer.Free;
  end;
end;

procedure LandrixGaebXmlWriteStream(ADocument: TLandrixGaebXmlGAEB; const ATarget: TLandrixGaebTarget;
  AStream: TStream; const AOptions: TLandrixGaebXmlWriteOptions; ADiagnostics: TLandrixGaebDiagnostics);
var
  S: TLandrixXmlUtf8;
begin
  S := LandrixGaebXmlWriteUtf8(ADocument, ATarget, AOptions, ADiagnostics);
  if S <> '' then
    AStream.WriteBuffer(S[1], Length(S));
end;

procedure LandrixGaebXmlWriteFile(ADocument: TLandrixGaebXmlGAEB; const ATarget: TLandrixGaebTarget;
  const AFileName: string; const AOptions: TLandrixGaebXmlWriteOptions;
  ADiagnostics: TLandrixGaebDiagnostics);
var
  S: TLandrixXmlUtf8;
  Stream: TFileStream;
begin
  S := LandrixGaebXmlWriteUtf8(ADocument, ATarget, AOptions, ADiagnostics);
  Stream := TFileStream.Create(AFileName, fmCreate);
  try
    if S <> '' then
      Stream.WriteBuffer(S[1], Length(S));
  finally
    Stream.Free;
  end;
end;

end.""" % write_proc(root))
    return "\r\n".join("\n".join(out).split("\n")) + "\r\n"


def main(argv):
    args = argv[1:]
    if len(args) > 1 or any(a not in ("--check", "--update-names") for a in args):
        fail("usage: gen-gaeb-model.py [--check | --update-names]")
    if not os.path.exists(MERGED):
        fail("%s missing, run extract-gaeb-xsd.py and merge-gaeb.py first" % MERGED)
    merged = json.load(io.open(MERGED, encoding="utf-8"))
    data = json.load(io.open(NAMES, encoding="utf-8")) if os.path.exists(NAMES) else {}
    names = Names(data, "--update-names" in args)
    model = Model(merged, names)
    model.build()
    names.prune()
    if names.missing:
        for m in names.missing[:40]:
            sys.stderr.write("  " + m + "\n")
        fail("%d name(s) missing or unused in names.json; run with --update-names and review the diff"
             % len(names.missing))
    if "--update-names" in args:
        text = json.dumps(names.data, indent=1, ensure_ascii=True, sort_keys=True) + "\n"
        io.open(NAMES, "w", encoding="utf-8", newline="\n").write(text)
        print("gen-gaeb-model: names.json updated")
    prof = Profiles(model)
    prof.build()
    units = [(MODEL_UNIT, gen_model(model)), (CODES_UNIT, gen_codes(model)),
             (READER_UNIT, gen_reader(model)), (PROFILES_UNIT, gen_profiles(model, prof)),
             (WRITER_UNIT, gen_writer(model, prof))]
    for path, text in units:
        if any(ord(ch) > 127 for ch in text):
            fail("%s: non-ASCII output" % path)
    if "--check" in args:
        status = 0
        for path, text in units:
            current = io.open(path, "rb").read() if os.path.exists(path) else None
            if current != text.encode("ascii"):
                sys.stderr.write("gen-gaeb-model: %s is not up to date\n" % os.path.basename(path))
                status = 1
        if status == 0:
            print("gen-gaeb-model: units up to date")
        return status
    for path, text in units:
        io.open(path, "wb").write(text.encode("ascii"))
        print("gen-gaeb-model: wrote %s (%d lines)" % (os.path.basename(path), text.count("\r\n")))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
