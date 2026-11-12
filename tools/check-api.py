#!/usr/bin/env python3
#
# GAEB-for-Pascal
#
# Copyright (C) 2026 Landrix Software GmbH & Co. KG
#
# This file is dual-licensed under:
# - GNU GPL version 3 or later; or
# - the Landrix Software Commercial License.
#
# See LICENSE and commercial.license.md.
#
# SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
"""Checks the interface of the stable units against a frozen baseline.

Every unit in source/ marked `{ API: stable.` is read once per compiler
configuration (Free Pascal, Delphi 6 to 2007, Delphi 2009 to 11, Delphi 12
and later; conditional compilation is evaluated with the defines of the
include files). Its interface section becomes a set of entries:

- type aliases (with `type` for a distinct type), sets and arrays as
  written; procedural types like routines;
- classes and objects with their ancestor, one entry per implemented
  interface, records;
- enumeration values (each one an entry, so values may be added);
- fields with their type, properties with their type and one entry per
  read access, write access and default property (class properties marked);
- routines and methods as their parameter modes and types, result type
  and binding directives (virtual, override, abstract, calling convention;
  not overload, parameter names or the grouping of parameters); one entry
  per parameter with a default value, with that value;
- constants with their declared type, or for an untyped constant the kind
  of its value (string, integer, real, boolean, expression); values may
  change;
- protected (also strict protected) members carry "(protected)"; private
  members are not entries.

An entry that holds only in some configurations names them in square
brackets. An entry of the baseline is kept if the sources still have it in
at least the same configurations and at least the same visibility. Anything
else is a break: a removal, a rename, a changed type, signature or
ancestor, a lost interface, a lost read or write access, a lost or changed
default value, a removed enumeration value, a member that became less
visible or a declaration that disappeared on one compiler. New entries are
allowed: the API only grows.

What the tool cannot judge it rejects (exit 2) instead of passing silently:
variant records, nested record types, {$ELSEIF}, {$H-}, conditional symbols
of a unit that no include file defines, and CompilerVersion thresholds
between the configurations.

The LandrixXml units that an interface of a stable unit uses (today
LandrixXmlBase and LandrixXmlDecimal) belong to the stable API as well; they
are read from the submodule external/landrix-xml. A new submodule pointer
that breaks them fails here, before it is committed.

Usage:
  python tools/check-api.py                  check all stable units
  python tools/check-api.py --units A,B      check only these units
  python tools/check-api.py --freeze         write the baseline from the sources

Freeze only on purpose (a release, or a break the owner decided); the diff
of the baseline then shows every change of the stable API.
"""

import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "source")
# LandrixXml units that an interface of a stable unit uses are part of the
# stable API too; they are checked from the submodule, so that pulling a
# new LandrixXml shows every break.
EXTERNAL = os.path.join(ROOT, "external", "landrix-xml", "source")
BASELINE = os.path.join(ROOT, "tools", "api-baseline.txt")
STABLE_MARK = "{ API: stable."

# name, defines, CompilerVersion (None: Free Pascal)
CONFIGS = [("fpc", {"FPC"}, None), ("d6", set(), 14.0), ("d2009", set(), 20.0), ("d12", set(), 36.0)]
VERSIONS = sorted(v for _, _, v in CONFIGS if v is not None)

ROUTINE = {"procedure", "function", "constructor", "destructor"}
BINDING = {"virtual", "dynamic", "override", "abstract", "final", "static", "stdcall", "cdecl",
           "register", "pascal", "safecall"}
IGNORED = {"overload", "reintroduce", "inline", "deprecated", "platform", "experimental"}
MODES = {"const", "var", "out", "constref"}
SECTIONS = {"type", "const", "var", "resourcestring", "threadvar", "uses"}
PROTECTED = " (protected)"
ENTRY = re.compile(r"^(.*?)( \(protected\))?( \[([a-z0-9,]+)\])?$")


def fail(msg):
    sys.stderr.write("check-api: " + msg + "\n")
    sys.exit(2)


# ---------------------------------------------------------------- text

def lex(text, where):
    """Pieces of the text: ('dir', directive), ('text', code); comments go."""
    out = []
    buf = []
    i = 0
    n = len(text)
    while i < n:
        c = text[i]
        if c == "'":
            j = i + 1
            while j < n:
                if text[j] == "'":
                    if j + 1 < n and text[j + 1] == "'":
                        j += 2
                        continue
                    break
                j += 1
            buf.append(text[i:j + 1])
            i = j + 1
        elif c == "{":
            j = text.find("}", i)
            if j < 0:
                fail("%s: unclosed comment" % where)
            if text.startswith("{$", i):
                out.append(("text", "".join(buf)))
                buf = []
                out.append(("dir", text[i + 2:j].strip()))
            else:
                buf.append(" ")
            i = j + 1
        elif text.startswith("(*", i):
            j = text.find("*)", i)
            if j < 0:
                fail("%s: unclosed comment" % where)
            if text.startswith("(*$", i):
                fail("%s: directive in (*$ *) not supported" % where)
            buf.append(" ")
            i = j + 2
        elif text.startswith("//", i):
            j = text.find("\n", i)
            i = n if j < 0 else j
        else:
            buf.append(c)
            i += 1
    out.append(("text", "".join(buf)))
    return out


def include_defines():
    """Every symbol an include file of the library or of LandrixXml defines."""
    found = {"FPC"}
    for folder in (SOURCE, EXTERNAL):
        if not os.path.isdir(folder):
            continue
        for name in os.listdir(folder):
            if name.lower().endswith(".inc"):
                text = io.open(os.path.join(folder, name), encoding="ascii", errors="replace").read()
                found |= set(s.upper() for s in re.findall(r"(?i)\{\$DEFINE\s+(\w+)", text))
    return found


KNOWN = None


def preprocess(path, defines, version, where, depth=0):
    """The code of a file as one configuration sees it; defines grow. In
    the unit itself (depth 0) everything that cannot be judged with the
    configurations is rejected; include files only set switches."""
    global KNOWN
    if KNOWN is None:
        KNOWN = include_defines()
    if depth > 4:
        fail("%s: includes nested too deep" % where)
    text = io.open(path, encoding="ascii", newline="").read()
    out = []
    stack = []  # [active, taken]

    def active():
        return all(s[0] for s in stack)

    def symbol(arg):
        sym = arg.split()[0].upper()
        if depth == 0 and sym not in KNOWN:
            fail("%s: {$IFDEF %s}: no include file defines it, no configuration covers it" % (where, sym))
        return sym

    def cond(expr):
        m = re.match(r"(?i)^CompilerVersion\s*>=\s*([0-9.]+)$", expr.strip())
        if m:
            if version is None:
                fail("%s: CompilerVersion outside {$IFNDEF FPC}" % where)
            t = float(m.group(1))
            if depth == 0 and t > VERSIONS[0] and t not in VERSIONS:
                fail("%s: CompilerVersion >= %s lies between the configurations; add one" % (where, t))
            return version >= t
        m = re.match(r"(?i)^Defined\s*\(\s*(\w+)\s*\)$", expr.strip())
        if m:
            return symbol(m.group(1)) in defines
        fail("%s: unsupported {$IF %s}" % (where, expr))

    for kind, piece in lex(text, where):
        if kind == "text":
            if active():
                out.append(piece)
            continue
        word = re.split(r"\s+", piece, maxsplit=1)
        name = word[0].upper()
        arg = word[1] if len(word) > 1 else ""
        if name == "IFDEF":
            c = symbol(arg) in defines
            stack.append([c, c])
        elif name == "IFNDEF":
            c = symbol(arg) not in defines
            stack.append([c, c])
        elif name == "IF":
            c = cond(arg) if active() else False
            stack.append([c, c])
        elif name in ("ELSEIF", "IFOPT"):
            fail("%s: {$%s} not supported" % (where, name))
        elif name == "ELSE":
            if not stack:
                fail("%s: {$ELSE} without {$IF}" % where)
            stack[-1][0] = not stack[-1][1]
        elif name in ("ENDIF", "IFEND"):
            if not stack:
                fail("%s: {$%s} without {$IF}" % (where, name))
            stack.pop()
        elif not active():
            continue
        elif name == "DEFINE":
            defines.add(arg.split()[0].upper())
        elif name == "UNDEF":
            defines.discard(arg.split()[0].upper())
        elif name in ("I", "INCLUDE"):
            inc = os.path.join(os.path.dirname(path), arg.strip())
            if not os.path.exists(inc):
                fail("%s: include %s not found" % (where, arg))
            out.append(preprocess(inc, defines, version, where, depth + 1))
        elif re.match(r"(?i)^H-", piece) or re.match(r"(?i)^LONGSTRINGS\s+OFF", piece):
            fail("%s: {$H-} changes what string means; not supported" % where)
        # other directives ($MODE, $H+, $WARN, ...) do not change declarations
    if stack:
        fail("%s: unclosed {$IF}" % where)
    return " ".join(out)


TOKEN = re.compile(r"'(?:[^']|'')*'|#\$?[0-9A-Fa-f]+|\$[0-9A-Fa-f]+|[A-Za-z_][A-Za-z_0-9]*|"
                   r"\d+(?:\.\d+)?(?:[eE][+-]?\d+)?|\.\.|:=|<>|<=|>=|\S")


def is_literal(tok):
    return tok.startswith("'") or tok.startswith("#")


def norm(toks):
    """Tokens as one string: identifiers lower case, literals as written;
    the spacing depends on the tokens only, never on literal contents."""
    out = ""
    prev = ""
    for t in toks:
        tok = t if is_literal(t) else t.lower()
        if not out:
            out = tok
        elif tok in (")", "]", ",", ";", ":", "..") or prev in ("(", "[", ".."):
            out += tok
        elif tok in ("(", "[") and not (prev in (",", ";", ":", "=") or prev in MODES):
            out += tok
        else:
            out += " " + tok
        if tok in (",", ";", ":"):
            out += " "
            prev = tok
            out = out.rstrip(" ") + " "
            continue
        prev = tok
    return re.sub(r" +", " ", out).strip()


def split_top(toks, sep):
    """Splits at sep on bracket depth 0."""
    parts = [[]]
    depth = 0
    for t in toks:
        if t in ("(", "["):
            depth += 1
        elif t in (")", "]"):
            depth -= 1
        if t == sep and depth == 0:
            parts.append([])
        else:
            parts[-1].append(t)
    return parts


def first_top(toks, sep):
    """Index of the first sep on bracket depth 0, -1 if none."""
    depth = 0
    for k, t in enumerate(toks):
        if t in ("(", "["):
            depth += 1
        elif t in (")", "]"):
            depth -= 1
        elif t == sep and depth == 0:
            return k
    return -1


def signature(head):
    """A routine or procedural type head: (text, [(parameter number,
    default value)]). Parameter names and their grouping do not count."""
    kind = head[0].lower()
    k = 1
    name = []
    while k < len(head) and head[k] not in ("(", ":"):
        name.append(head[k])
        k += 1
    params = []
    defaults = []
    if k < len(head) and head[k] == "(":
        depth = 0
        j = k
        while True:
            if head[j] == "(":
                depth += 1
            elif head[j] == ")":
                depth -= 1
                if depth == 0:
                    break
            j += 1
        inner = head[k + 1:j]
        k = j + 1
        for group in split_top(inner, ";"):
            if not group:
                continue
            mode = ""
            if group[0].lower() in MODES:
                mode = group[0].lower() + " "
                group = group[1:]
            colon = first_top(group, ":")
            names = group if colon < 0 else group[:colon]
            typ = ""
            default = None
            if colon >= 0:
                rest = group[colon + 1:]
                eq = first_top(rest, "=")
                typ = norm(rest if eq < 0 else rest[:eq])
                if eq >= 0:
                    default = norm(rest[eq + 1:])
            for x in names:
                if x == ",":
                    continue
                if default is not None:
                    defaults.append((len(params) + 1, default))
                params.append((mode + typ).strip())
    result = ""
    tail = head[k:]
    if tail and tail[0] == ":":
        tail = tail[1:]
        of = len(tail)
        if len(tail) >= 2 and tail[-2].lower() == "of" and tail[-1].lower() == "object":
            of = len(tail) - 2
        result = ": " + norm(tail[:of])
        tail = tail[of:]
    extra = (" " + norm(tail)) if tail else ""
    text = "%s %s(%s)%s%s" % (kind, norm(name), ", ".join(params), result, extra)
    return re.sub(r" \(", "(", text.replace("%s (" % kind, "%s(" % kind)), defaults


# ---------------------------------------------------------------- parser

class Parser(object):
    def __init__(self, toks, unit):
        self.t = toks
        self.i = 0
        self.unit = unit
        self.entries = set()

    def peek(self, k=0):
        j = self.i + k
        return self.t[j].lower() if j < len(self.t) else ""

    def take(self):
        if self.i >= len(self.t):
            fail("%s: unexpected end of the interface" % self.unit)
        tok = self.t[self.i]
        self.i += 1
        return tok

    def expect(self, tok):
        got = self.take()
        if got.lower() != tok:
            fail("%s: '%s' expected, found '%s'" % (self.unit, tok, got))

    def until_semicolon(self):
        depth = 0
        out = []
        while True:
            tok = self.take()
            if tok in ("(", "["):
                depth += 1
            elif tok in (")", "]"):
                depth -= 1
            elif tok == ";" and depth == 0:
                return out
            out.append(tok)

    def directives(self):
        out = []
        while True:
            w = self.peek()
            if w in BINDING | IGNORED | {"default"} and self.peek(1) == ";":
                out.append(self.take().lower())
                self.take()
            elif w == "deprecated" and is_literal(self.t[self.i + 1] if self.i + 1 < len(self.t) else "") \
                    and self.peek(2) == ";":
                self.take()
                self.take()
                self.take()
            else:
                return out

    def add(self, entry):
        self.entries.add(self.unit + ": " + entry)

    def routine(self, owner, protected):
        head = self.until_semicolon()
        prefix = ""
        if head[0].lower() == "class":
            prefix = "class "
            head = head[1:]
        binding = sorted(d for d in self.directives() if d in BINDING)
        text, defaults = signature(head)
        text = (owner + " " if owner else "") + prefix + text
        if binding:
            text += "; " + "; ".join(binding)
        suffix = PROTECTED if protected else ""
        self.add(text + suffix)
        for number, value in defaults:
            self.add("%s default of parameter %d = %s%s" % (text, number, value, suffix))

    def prop(self, owner, protected, prefix):
        body = self.until_semicolon()
        dirs = self.directives()
        name = body[0].lower()
        k = 1
        index = ""
        if k < len(body) and body[k] == "[":
            j = body.index("]", k)
            types = []
            for group in split_top(body[k + 1:j], ";"):
                mode = ""
                if group and group[0].lower() in MODES:
                    mode = group[0].lower() + " "
                    group = group[1:]
                colon = first_top(group, ":")
                if colon < 0:
                    fail("%s: property %s: index parameter without type" % (self.unit, name))
                for x in group[:colon]:
                    if x != ",":
                        types.append(mode + norm(group[colon + 1:]))
            index = "[" + ", ".join(types) + "]"
            k = j + 1
        if k >= len(body) or body[k] != ":":
            fail("%s: property %s: redeclaration without type not supported" % (self.unit, name))
        k += 1
        typ = []
        while k < len(body) and body[k].lower() not in ("read", "write", "index", "stored", "default",
                                                       "nodefault", "implements"):
            typ.append(body[k])
            k += 1
        suffix = PROTECTED if protected else ""
        base = "%s %sproperty %s%s" % (owner, prefix, name, index)
        self.add("%s: %s%s" % (base, norm(typ), suffix))
        words = [w.lower() for w in body[k:]]
        for access in ("read", "write"):
            if access in words:
                self.add("%s %s%s" % (base, access, suffix))
        if "default" in dirs:
            self.add("%s default property%s" % (base, suffix))

    def field_type(self, owner, typ):
        if not typ:
            fail("%s: %s: field without type" % (self.unit, owner))
        w = [t.lower() for t in typ[:2]]
        if w[0] == "record" or w == ["packed", "record"] or w[0] in ("class", "object"):
            fail("%s: %s: nested record or class types are not supported" % (self.unit, owner))
        if w[0] in ROUTINE:
            return signature(typ)[0]
        return norm(typ)

    def fields(self, owner, toks, protected):
        colon = first_top(toks, ":")
        if colon < 0:
            fail("%s: %s: declaration '%s' not understood" % (self.unit, owner, " ".join(toks)))
        typ = self.field_type(owner, toks[colon + 1:])
        suffix = PROTECTED if protected else ""
        for name in toks[:colon]:
            if name != ",":
                self.add("%s field %s: %s%s" % (owner, name.lower(), typ, suffix))

    def members(self, owner, is_class):
        visibility = "public"
        while True:
            w = self.peek()
            if w == "end":
                self.take()
                self.expect(";")
                return
            if w == "case":
                fail("%s: %s: variant records are not supported" % (self.unit, owner))
            if is_class and w in ("private", "protected", "public", "published", "strict"):
                self.take()
                if w == "strict":
                    visibility = self.take().lower()
                else:
                    visibility = w
                continue
            hidden = visibility == "private"
            protected = visibility == "protected"
            prefix = ""
            if w == "class" and self.peek(1) == "property":
                self.take()
                prefix = "class "
                w = "property"
            if w in ROUTINE or (w == "class" and self.peek(1) in ROUTINE):
                if hidden:
                    self.until_semicolon()
                    self.directives()
                else:
                    self.routine(owner, protected)
                continue
            if w == "property":
                self.take()
                if hidden:
                    self.until_semicolon()
                    self.directives()
                else:
                    self.prop(owner, protected, prefix)
                continue
            toks = self.until_semicolon()
            if not hidden:
                self.fields(owner, toks, protected)

    def heritage(self):
        names = []
        if self.peek() == "(":
            self.take()
            while True:
                tok = self.take()
                if tok == ")":
                    break
                if tok != ",":
                    names.append(tok.lower())
        return names

    def type_decl(self):
        name = self.take().lower()
        self.expect("=")
        strong = ""
        if self.peek() == "type":
            self.take()
            strong = "type "
        if self.peek() == "packed" and self.peek(1) in ("record", "object", "class"):
            fail("%s: %s: packed records and classes are not supported" % (self.unit, name))
        w = self.peek()
        if w == "class" and self.peek(1) == ";":
            self.take()
            self.take()
            return
        if w == "class" and self.peek(1) == "of":
            self.add("type %s = %s%s" % (name, strong, norm(self.until_semicolon())))
            return
        if w in ("class", "object"):
            self.take()
            heritage = self.heritage()
            if w == "class" and not heritage:
                heritage = ["tobject"]
            self.add("%s %s(%s)" % (w, name, heritage[0] if heritage else ""))
            for intf in heritage[1:]:
                self.add("%s %s implements %s" % (w, name, intf))
            if self.peek() == ";":
                self.take()
                return
            self.members(name, True)
            return
        if w == "record":
            self.take()
            self.add("record %s" % name)
            self.members(name, False)
            return
        if w == "(":
            self.take()
            self.add("enum %s" % name)
            body = []
            while True:
                tok = self.take()
                if tok == ")":
                    break
                body.append(tok)
            for value in split_top(body, ","):
                if value:
                    self.add("enum %s value %s" % (name, value[0].lower()))
            self.expect(";")
            return
        toks = self.until_semicolon()
        if toks and toks[0].lower() in ROUTINE:
            dirs = sorted(d for d in self.directives() if d in BINDING)
            text = signature(toks)[0]
            if dirs:
                text += "; " + "; ".join(dirs)
            self.add("type %s = %s%s" % (name, strong, text))
            return
        self.add("type %s = %s%s" % (name, strong, norm(toks)))

    def constant(self):
        name = self.take().lower()
        toks = self.until_semicolon()
        if toks and toks[0] == ":":
            eq = first_top(toks[1:], "=")
            self.add("const %s: %s" % (name, norm(toks[1:] if eq < 0 else toks[1:eq + 1])))
            return
        value = [t for t in (toks[1:] if toks and toks[0] == "=" else toks)]
        words = [t for t in value if t not in ("(", ")", "+", "-", "*")]
        if words and all(is_literal(t) for t in words):
            kind = "string"
        elif words and all(re.match(r"^(\d+|\$[0-9A-Fa-f]+)$", t) for t in words):
            kind = "integer"
        elif words and all(re.match(r"^(\d+(\.\d+)?([eE][+-]?\d+)?|\$[0-9A-Fa-f]+|/)$", t) for t in words):
            kind = "real"
        elif len(words) == 1 and words[0].lower() in ("true", "false"):
            kind = "boolean"
        else:
            kind = "expression"
        self.add("const %s (%s)" % (name, kind))

    def parse(self):
        section = ""
        while self.i < len(self.t):
            w = self.peek()
            if w in SECTIONS:
                self.take()
                section = w
                if w == "uses":
                    self.until_semicolon()
                    section = ""
                continue
            if w in ROUTINE:
                self.routine("", False)
                continue
            if section == "type":
                self.type_decl()
            elif section in ("const", "resourcestring"):
                self.constant()
            elif section in ("var", "threadvar"):
                self.fields("var", self.until_semicolon(), False)
            else:
                fail("%s: unexpected token '%s'" % (self.unit, self.t[self.i]))
        return self.entries


# ---------------------------------------------------------------- units

def interface_tokens(code, where):
    toks = TOKEN.findall(code)
    low = [t.lower() for t in toks]
    if "interface" not in low or "implementation" not in low:
        fail("%s: no interface or implementation section" % where)
    a = low.index("interface")
    b = low.index("implementation", a)
    return toks[a + 1:b]


def unit_path(unit):
    for folder in (SOURCE, EXTERNAL):
        if os.path.isdir(folder):
            for name in os.listdir(folder):
                if name.lower() == unit.lower() + ".pas":
                    return os.path.join(folder, name)
    fail("unit %s not found" % unit)


def unit_entries(unit):
    """Entries of a unit, each with the configurations it holds in."""
    path = unit_path(unit)
    per = {}
    for name, defines, version in CONFIGS:
        code = preprocess(path, set(defines), version, unit)
        for e in Parser(interface_tokens(code, unit), unit).parse():
            per.setdefault(e, []).append(name)
    everywhere = len(CONFIGS)
    result = set()
    for e, names in per.items():
        result.add(e if len(names) == everywhere else "%s [%s]" % (e, ",".join(sorted(names))))
    return result


def interface_uses(unit):
    """Units of the interface uses clause, in any configuration."""
    found = set()
    for _, defines, version in CONFIGS:
        toks = interface_tokens(preprocess(unit_path(unit), set(defines), version, unit), unit)
        if toks and toks[0].lower() == "uses":
            k = toks.index(";")
            found |= set(t for t in toks[1:k] if t != ",")
    return found


def stable_units():
    """The stable units of source/, then the LandrixXml units their
    interfaces use (with the spelling of their file names)."""
    units = []
    for name in sorted(os.listdir(SOURCE)):
        if not name.lower().endswith(".pas"):
            continue
        text = io.open(os.path.join(SOURCE, name), encoding="ascii", newline="").read()
        if STABLE_MARK in text:
            units.append(name[:-4])
    files = {}
    if os.path.isdir(EXTERNAL):
        files = dict((n[:-4].lower(), n[:-4]) for n in os.listdir(EXTERNAL) if n.lower().endswith(".pas"))
    external = set()
    for unit in units:
        for used in interface_uses(unit):
            if used.lower() in files:
                external.add(files[used.lower()])
    return units + sorted(external)


def split_entry(entry):
    m = ENTRY.match(entry)
    configs = set(m.group(4).split(",")) if m.group(4) else set(n for n, _, _ in CONFIGS)
    return m.group(1), bool(m.group(2)), configs


def kept(entry, index):
    """The baseline entry still holds: same declaration, in at least the
    same configurations, at least as visible."""
    base, protected, configs = split_entry(entry)
    have = set()
    for cur_protected, cur_configs in index.get(base, []):
        if protected or not cur_protected:
            have |= cur_configs
    return configs <= have


def main(argv):
    args = argv[1:]
    only = None
    if "--units" in args:
        k = args.index("--units")
        if k + 1 >= len(args):
            fail("--units needs a list")
        only = [u for u in args[k + 1].split(",") if u]
        args = args[:k] + args[k + 2:]
    freeze = args == ["--freeze"]
    if args and not freeze or (freeze and only):
        fail("usage: check-api.py [--freeze | --units A,B]")
    units = stable_units()
    if only is not None:
        for u in only:
            if u not in units:
                fail("%s is not a stable unit" % u)
    current = set()
    for unit in (only or units):
        current |= unit_entries(unit)
    if freeze:
        text = "".join(sorted(e + "\n" for e in current))
        io.open(BASELINE, "w", encoding="ascii", newline="\n").write(text)
        print("check-api: baseline written, %d entries of %d unit(s)" % (len(current), len(units)))
        return 0
    if not os.path.exists(BASELINE):
        fail("%s missing; run with --freeze" % BASELINE)
    baseline = set(line.rstrip("\n") for line in io.open(BASELINE, encoding="ascii") if line.strip())
    if only is not None:
        baseline = set(e for e in baseline if e.split(": ", 1)[0] in only)
    index = {}
    for e in current:
        base, protected, configs = split_entry(e)
        index.setdefault(base, []).append((protected, configs))
    gone_units = sorted(set(e.split(": ", 1)[0] for e in baseline) - set(units))
    missing = sorted(e for e in baseline if not kept(e, index))
    added = len(current - baseline)
    for u in gone_units:
        sys.stderr.write("check-api: stable unit %s is gone or no longer stable\n" % u)
    for e in missing:
        sys.stderr.write("check-api: removed or changed: %s\n" % e)
    if missing or gone_units:
        sys.stderr.write("check-api: %d break(s) of the stable API\n" % len(missing))
        return 1
    print("check-api: %d entries kept, %d new or changed" % (len(baseline), added))
    sys.stdout.flush()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
