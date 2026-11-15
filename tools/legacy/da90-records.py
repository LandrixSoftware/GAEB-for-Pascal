#!/usr/bin/env python3
"""Checks tools/legacy/da90-records.json, the table of GAEB 90 record types,
and compares it with a folder of GAEB 90 files.

  python tools/legacy/da90-records.py --check
      consistency of the table: the common fields, every record covers
      columns 3 to 74 without gaps or overlaps, lengths and scales agree,
      sign and third-decimal links point to fitting fields, phases, codes
      and sequences refer to known records.

  python tools/legacy/da90-records.py --corpus <folder>
      reads every GAEB 90 file below <folder> and counts, per record type
      and field, what the table does not expect: record lengths, unknown
      record types, empty required fields, malformed numbers and dates,
      codes outside the allowed values, gaps in the record numbers, records
      a phase does not exchange or misses. Prints record types, field
      names, counts, OZ mask patterns and one- or two-character codes only,
      never other values or file names: the files may hold customer data.

Exit code 0 = the table is consistent (and, with --corpus, every file could
be read); differences against the corpus are findings, not errors.
"""
import argparse
import collections
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
TABLE = os.path.join(HERE, "da90-records.json")
TYPES = {"alpha", "text", "num", "int", "zz", "sign", "date", "time", "oz", "ozmask", "code", "filler"}
STATES = {"must", "may", "mustIfPrices", "mayIfPrices", "mustIfFreeQuantity", "mustInLongForm",
          "mustIfBidderText"}
PHASES = {"81", "82", "83", "84", "85", "86"}
RECORD = re.compile(r"^(T[019]|[0-9]{2})$")
FIELD_KEYS = {"name", "from", "to", "required", "type", "scale", "sign", "thirdDecimal", "values",
              "onlySpaceInPhases", "spaceMeans", "note"}


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


def digits(s):
    """True for a non-empty run of the ASCII digits 0-9 only."""
    return bool(s) and all("0" <= c <= "9" for c in s)


def fields_of(record):
    """The fields of a record; a lot list (record 35) is expanded."""
    if "lotList" in record:
        lot = record["lotList"]
        out = [{"name": "LOSGRNR", "from": 3, "to": 4, "required": True, "type": "alpha"}]
        for i in range(lot["count"]):
            start = lot["from"] + 2 * i
            out.append({"name": "%s%d" % (lot["name"], i + 1), "from": start, "to": start + 1,
                        "required": i < lot["required"], "type": "alpha"})
        return out
    return record.get("fields", [])


def check_field(fw, f, problems):
    """Checks one field on its own; False if its columns are unusable."""
    for k in f:
        if k not in FIELD_KEYS:
            problems.append("%s: unknown property %s" % (fw, k))
    for k in ("name", "from", "to", "type"):
        if k not in f:
            problems.append("%s: %s missing" % (fw, k))
    if not isinstance(f.get("name"), str) or not f.get("name"):
        problems.append("%s: name must be a string" % fw)
    if "required" in f and not isinstance(f["required"], bool):
        problems.append("%s: required must be true or false" % fw)
    if not (is_int(f.get("from")) and is_int(f.get("to"))):
        problems.append("%s: from and to must be integers" % fw)
        return False
    if f["to"] < f["from"]:
        problems.append("%s: ends before it starts" % fw)
        return False
    length = f["to"] - f["from"] + 1
    t = f.get("type")
    if t not in TYPES:
        problems.append("%s: unknown type %s" % (fw, t))
    if t == "num":
        s = f.get("scale")
        if not (isinstance(s, list) and len(s) == 2 and all(is_int(x) for x in s)
                and s[0] >= 0 and s[1] >= 0 and s[0] + s[1] == length):
            problems.append("%s: scale must be [integer, fraction] adding up to %d" % (fw, length))
    elif "scale" in f:
        problems.append("%s: scale only for num" % fw)
    for link in ("sign", "thirdDecimal"):
        if link in f and t != "num":
            problems.append("%s: %s only for num" % (fw, link))
    fixed = {"sign": 1, "date": 8, "time": 5, "oz": 9, "ozmask": 9, "zz": 4}
    if t in fixed and length != fixed[t]:
        problems.append("%s: %s needs %d columns" % (fw, t, fixed[t]))
    if t == "code":
        v = f.get("values")
        if not (isinstance(v, list) and v and all(isinstance(x, str) and len(x) == length
                                                   and x.strip() == x for x in v)):
            problems.append("%s: values must be codes of %d characters" % (fw, length))
    elif "values" in f:
        problems.append("%s: values only for code" % fw)
    if "onlySpaceInPhases" in f:
        ph = f["onlySpaceInPhases"]
        if t != "code" or not (isinstance(ph, list) and ph and all(x in PHASES for x in ph)):
            problems.append("%s: onlySpaceInPhases needs a code field and known phases" % fw)
    if t == "filler" and f.get("required"):
        problems.append("%s: a filler cannot be required" % fw)
    return True


def check(table):
    """Problems of the table; a malformed shape is one problem, not a crash."""
    problems = []
    try:
        check_table(table, problems)
    except (KeyError, IndexError, TypeError, AttributeError, ValueError) as e:
        problems.append("table shape: %s %s" % (type(e).__name__, e))
    return problems


def check_table(table, problems):
    n = table.get("recordLength")
    if n != 80:
        problems.append("recordLength must be 80")
        n = 80
    common = table.get("common", [])
    want = [("ZA", 1, 2, "alpha"), ("SATZNR", 75, 80, "int")]
    got = [(f.get("name"), f.get("from"), f.get("to"), f.get("type")) for f in common]
    if got != want or not all(f.get("required") is True for f in common):
        problems.append("common: must be ZA 1-2 alpha and SATZNR 75-80 int, both required")
    for f in common:
        check_field("common/%s" % f.get("name"), f, problems)
    records = table["records"]
    for za, rec in records.items():
        where = "record " + za
        if not RECORD.match(za):
            problems.append("%s: record type must be T0/T1/T9 or two digits" % where)
        if "max" in rec and not (is_int(rec["max"]) and rec["max"] >= 0):
            problems.append("%s: max must be an integer, 0 = any number" % where)
        if "fields" in rec and "lotList" in rec:
            problems.append("%s: fields and lotList both given" % where)
        if "lotList" in rec:
            lot = rec["lotList"]
            if not (is_int(lot.get("from")) and is_int(lot.get("count")) and is_int(lot.get("required"))
                    and lot["count"] > 0 and 0 <= lot["required"] <= lot["count"]):
                problems.append("%s: lotList needs from, count and required (0 to count)" % where)
                continue
        fields = fields_of(rec)
        if not fields:
            problems.append("%s: no fields" % where)
            continue
        column = 3
        names = {}
        usable = True
        for f in fields:
            fw = "%s/%s" % (where, f.get("name"))
            if not check_field(fw, f, problems):
                usable = False
                continue
            if f["from"] != column:
                problems.append("%s: starts at %d, expected %d" % (fw, f["from"], column))
            column = f["to"] + 1
            if f.get("type") != "filler":
                if f["name"] in names:
                    problems.append("%s: name twice in the record" % fw)
                names[f["name"]] = f
        if usable and column != n - 6 + 1:
            problems.append("%s: fields end at %d, expected %d" % (where, column - 1, n - 6))
        for f in fields:
            if "sign" in f:
                other = names.get(f["sign"])
                if other is None or other.get("type") != "sign" or other.get("to") != f.get("from") - 1:
                    problems.append("%s/%s: sign %s is not the sign field right before it"
                                    % (where, f["name"], f["sign"]))
            if "thirdDecimal" in f:
                other = names.get(f["thirdDecimal"])
                if (other is None or other.get("type") != "int" or other.get("from") != other.get("to")
                        or other.get("from") != f.get("to") + 1 or f.get("scale", [0, 0])[1] != 2):
                    problems.append("%s/%s: thirdDecimal %s is not the one-digit int field right after a"
                                    " two-decimal num" % (where, f["name"], f["thirdDecimal"]))
        if "marker" in rec:
            m = rec["marker"]
            hit = [f for f in fields if f.get("from") == m.get("column") == f.get("to")]
            if not hit or hit[0].get("values") != [m.get("value")]:
                problems.append("%s: marker column is not a one-value code field" % where)
    lo, hi = table["freeRecordTypes"]
    for za, rec in records.items():
        free = za.isdigit() and lo <= int(za) <= hi
        if free and za != "79" and not rec.get("vendor"):
            problems.append("record %s: in the free range but not marked vendor" % za)
        if rec.get("vendor") and not free:
            problems.append("record %s: vendor record outside the free range" % za)
    for za in table["undefinedRecordTypes"]:
        if za in records:
            problems.append("record %s: listed as undefined and described" % za)
    if set(table["phases"]) != PHASES:
        problems.append("phases must be exactly 81 to 86")
    for dp, ph in table["phases"].items():
        for za, state in ph["records"].items():
            if za not in records:
                problems.append("phase %s: unknown record %s" % (dp, za))
            elif records[za].get("vendor"):
                problems.append("phase %s: vendor record %s" % (dp, za))
            if state not in STATES:
                problems.append("phase %s: unknown state %s" % (dp, state))
        for za in ("00", "01", "02", "99"):
            if ph["records"].get(za) != "must":
                problems.append("phase %s: record %s must be required" % (dp, za))
    for dp, how in table.get("bidderTexts", {}).items():
        if dp not in PHASES or how not in ("always", "shortForm"):
            problems.append("bidderTexts: bad entry %s" % dp)
    dps = [f for f in records["00"]["fields"] if f["name"] == "DP"][0]["values"]
    if sorted(dps) != sorted(PHASES):
        problems.append("record 00: DP values must be 81 to 86")
    p = {f["name"]: f for f in records["21"]["fields"]}
    for kind in table["positionKinds"]:
        if not (len(kind) == 3 and kind[0] in p["POSART1"]["values"] and kind[1] in p["POSART2"]["values"]
                and kind[2] in p["POSTYP"]["values"]):
            problems.append("position kind %s: not made of POSART1/POSART2/POSTYP codes" % kind)
    for ctx, seq in table["sequence"].items():
        for entry in seq:
            if not (isinstance(entry, list) and len(entry) == 2 and entry[0] in records
                    and is_int(entry[1]) and entry[1] >= 0):
                problems.append("sequence %s: bad entry %s" % (ctx, entry))
            elif entry[1] != records[entry[0]].get("max", 1):
                problems.append("sequence %s: %s count differs from the record max" % (ctx, entry[0]))
    for ctx, pl in table.get("placement", {}).items():
        if ctx not in table["sequence"]:
            problems.append("placement %s: no such sequence" % ctx)
        for k in ("before", "after", "parent", "parts"):
            if k in pl and pl[k] not in table["sequence"]:
                problems.append("placement %s: %s %s is no sequence" % (ctx, k, pl[k]))
        for za in pl.get("optional", []):
            if za not in records:
                problems.append("placement %s: unknown record %s" % (ctx, za))
    mask = [f for f in records["00"]["fields"] if f.get("type") == "ozmask"]
    om = table["ozMask"]
    if (len(mask) != 1 or om.get("length") != mask[0]["to"] - mask[0]["from"] + 1
            or not all(isinstance(om.get(k), str) and len(om[k]) == 1 for k in ("item", "index", "fill"))):
        problems.append("ozMask: length must match OZMASKE, item/index/fill one character each")
    # the corpus check (MASK) knows these symbols only
    if (om.get("levels") != ["1", "2", "3", "4"] or om.get("item") != "P" or om.get("index") != "I"
            or om.get("fill") != "0"):
        problems.append("ozMask: levels 1 to 4, item P, index I, fill 0 expected")
    for ctx, pl in table.get("placement", {}).items():
        if "max" in pl and not (is_int(pl["max"]) and 1 <= pl["max"] <= 999):
            problems.append("placement %s: max must be 1 to 999" % ctx)


# ---- corpus ----

CODE = re.compile(r"^[A-Za-z0-9]{1,2}$")
MASK = re.compile(r"^[1234PI0 ]{9}$")
DATE = re.compile(r"^[0-9]{2}\.[0-9]{2}\.[0-9]{2}$")
TIME = re.compile(r"^[0-9]{2}:[0-9]{2}$")
DESCRIPTION_START = {"20", "21", "24", "42"}


def records_of(data, phys):
    """The records of a file as strings; counts the physical quirks in phys."""
    end = data.rstrip(b"\r\n")
    if end.endswith(b"\x1a"):
        phys["Ctrl-Z at the end"] += 1
        data = end.rstrip(b"\x1a")
    if b"\x1a" in data:
        phys["Ctrl-Z inside"] += 1
    if data.startswith(b"\xef\xbb\xbf"):
        phys["UTF-8 BOM"] += 1
        data = data[3:]
    # a file that is valid UTF-8 with multi-byte sequences is read as UTF-8
    # (columns count characters); anything else byte by byte
    text = None
    if any(b > 127 for b in data):
        try:
            text = data.decode("utf-8")
            phys["UTF-8"] += 1
        except UnicodeDecodeError:
            text = None
    if text is None:
        text = data.decode("latin-1")
    if "\r\r\n" in text:
        phys["CR CR LF line ends"] += 1
    out = []
    glued = False
    for line in text.split("\n"):
        line = line.rstrip("\r")
        # records of 80 characters chained with NUL NUL instead of a line end
        while len(line) > 80 and line[80:82] == "\x00\x00":
            glued = True
            out.append(line[:80])
            line = line[82:]
        out.append(line)
    if glued:
        phys["records glued with NUL NUL"] += 1
    if any("\x00" in r for r in out):
        phys["NUL inside records (read as space)"] += 1
        out = [r.replace("\x00", " ") for r in out]
    while out and not out[-1].strip():
        out.pop()
    if any(not r.strip() for r in out):
        phys["blank lines inside"] += 1
    return [r for r in out if r.strip()]


def is_gaeb90(recs, table):
    """The first or second record looks like a GAEB 90 record."""
    for r in recs[:2]:
        if r[:2] in table["records"] and len(r) >= 80 and digits(r[74:80]):
            return True
    return False


def blank(v):
    """True if v holds spaces only (a tab or other white space is content)."""
    return all(c == " " for c in v)


def shown_code(value):
    return value if CODE.match(value) else "<other>"


class FileState(object):
    """What one file has shown so far."""

    def __init__(self):
        self.dp = None
        self.longform = False
        self.prices = False
        self.seen = collections.Counter()
        self.positions = set()
        self.free_qty = set()
        self.with_21 = set()
        self.free_21 = set()
        self.asks_bidder = False
        self.bidder_text = False
        self.open_bidder = 0
        self.desc_oz = None


def close_description(st):
    if st.asks_bidder and not st.bidder_text:
        st.open_bidder += 1
    st.asks_bidder = st.bidder_text = False


def corpus(table, folder):
    records = table["records"]
    fields = {za: fields_of(rec) for za, rec in records.items()}
    lo, hi = table["freeRecordTypes"]
    p21 = {f["name"]: f["values"] for f in fields["21"] if f["type"] == "code"}
    p1, p2, pt = p21["POSART1"], p21["POSART2"], p21["POSTYP"]
    files = skipped = unreadable = 0
    phys = collections.Counter()
    phases = collections.Counter()
    editions = collections.Counter()
    types = collections.Counter()
    unknown = collections.Counter()
    lengths = collections.Counter()
    findings = collections.Counter()
    codes = collections.Counter()
    masks = collections.Counter()
    phase_extra = collections.Counter()
    phase_missing = collections.Counter()
    walk_errors = []
    for root, _dirs, names in os.walk(folder, onerror=walk_errors.append):
        for n in sorted(names):
            try:
                with open(os.path.join(root, n), "rb") as f:
                    data = f.read()
            except OSError:
                unreadable += 1
                continue
            if data.lstrip()[:6].lower() == b"#begin" or data[:5] == b"<?xml":
                skipped += 1
                continue
            mine = collections.Counter()
            recs = records_of(data, mine)
            if not is_gaeb90(recs, table):
                skipped += 1
                continue
            phys.update(mine)
            files += 1
            st = FileState()
            last_nr = None
            gaps = in_lv = t_inside = False
            closing = None
            closing_ordinal = 0
            for ordinal, r in enumerate(recs, 1):
                za = r[:2]
                if len(r) != 80:
                    lengths["%s %s" % (za if RECORD.match(za) else "??", "short" if len(r) < 80 else "long")] += 1
                r = r.ljust(80)[:80]
                nr = r[74:80]
                if digits(nr):
                    if last_nr is not None and int(nr) != last_nr + 1:
                        gaps = True
                    last_nr = int(nr)
                else:
                    findings["SATZNR not digits"] += 1
                rec = records.get(za)
                if rec is None:
                    if blank(za):
                        unknown["<no record type> %s" % ("all spaces" if blank(r[2:74]) else "with text")] += 1
                    elif digits(za) and lo <= int(za) <= hi:
                        unknown["%s (free range)" % za] += 1
                    elif RECORD.match(za):
                        unknown[za] += 1
                    else:
                        unknown["<not a record type>"] += 1
                    continue
                types[za] += 1
                st.seen[za] += 1
                oz = r[2:11]
                if za in DESCRIPTION_START or za in ("11", "31", "99") or za == "23" and oz != st.desc_oz:
                    close_description(st)
                if za in ("21", "23"):
                    st.desc_oz = oz
                if za == "00":
                    in_lv = True
                elif za == "99":
                    in_lv = False
                    closing = r
                    closing_ordinal = ordinal
                elif za[0] == "T" and in_lv:
                    t_inside = True
                if za in ("21", "22", "23"):
                    st.positions.add(oz)
                if za == "21":
                    st.with_21.add(oz)
                    if r[21] == "X":
                        st.free_21.add(oz)
                if za == "23" and not blank(r[37:48]):
                    st.free_qty.add(oz)
                m = rec.get("marker")
                if m and r[m["column"] - 1] != m["value"]:
                    # another layout under a vendor record type: not checked further
                    findings["%s without its marker" % za] += 1
                    continue
                for f in fields[za]:
                    v = r[f["from"] - 1:f["to"]]
                    t = f["type"]
                    key = "%s/%s" % (za, f["name"])
                    if st.dp in f.get("onlySpaceInPhases", []):
                        if not blank(v):
                            findings[key + " not a space in phase " + st.dp] += 1
                        continue
                    if blank(v):
                        if f["name"] == "VERSDTA":
                            editions["1985 (space)"] += 1
                        elif f.get("required"):
                            findings[key + " required but empty"] += 1
                        continue
                    if t in ("num", "int") and not digits(v):
                        if digits(v.lstrip(" ")):
                            how = "leading spaces"
                        elif digits(v.rstrip(" ")):
                            how = "trailing spaces"
                        elif digits(v.replace(" ", "")):
                            how = "inner spaces"
                        else:
                            how = "other characters"
                        findings["%s not digits (%s)" % (key, how)] += 1
                    elif t == "zz" and not (digits(v[:3]) and (v[3] == " " or digits(v[3]))):
                        findings[key + " not a ZZ"] += 1
                    elif t == "sign" and v != "-":
                        findings[key + " not a minus"] += 1
                    elif t == "date" and not DATE.match(v):
                        findings[key + " not DD.MM.YY"] += 1
                    elif t == "time" and not TIME.match(v):
                        findings[key + " not HH:MM"] += 1
                    elif t == "ozmask":
                        masks[v if MASK.match(v) else "<other>"] += 1
                    elif t == "code" and v not in f["values"]:
                        codes["%s %s" % (key, shown_code(v.strip(" ")))] += 1
                    if f["name"] == "DP":
                        st.dp = v
                    elif f["name"] == "KURZLANG":
                        st.longform = v == "L"
                    elif f["name"] == "KZPREIS":
                        st.prices = v == "X"
                    elif f["name"] == "VERSDTA" and v in f.get("values", []):
                        editions[v] += 1
                    elif f["name"] == "TB" and v == "X":
                        st.asks_bidder = True
                    elif f["name"] == "TEKZ" and v == "B":
                        st.bidder_text = True
                if za == "26" and st.dp in table["phases"]:
                    bidder_line = r[4] == "B"
                    state = table["phases"][st.dp]["records"].get("26")
                    if bidder_line and st.dp not in table.get("bidderTexts", {}):
                        findings["26 TEKZ B in phase %s" % st.dp] += 1
                    elif not bidder_line and state == "mustIfBidderText":
                        findings["26 without TEKZ B in phase %s" % st.dp] += 1
                    elif not bidder_line and state == "mustInLongForm" and not st.longform:
                        findings["26 without TEKZ B in short form, phase %s" % st.dp] += 1
                if za == "21":
                    kind = r[11:14]
                    if kind not in table["positionKinds"] and kind[0] in p1 and kind[1] in p2 and kind[2] in pt:
                        # each part is a defined one-character code
                        codes["21 POSART1 %s POSART2 %s POSTYP %s (combination)" % tuple(kind)] += 1
            close_description(st)
            dp = st.dp
            phases[dp if dp in table["phases"] else ("none" if dp is None else shown_code(dp.strip(" ")))] += 1
            if gaps:
                findings["file(s) with gaps in SATZNR"] += 1
            if t_inside:
                findings["file(s) with T records inside the bill"] += 1
            if "00" not in st.seen:
                findings["file(s) without 00"] += 1
            if closing is not None:
                anz = closing[69:74]
                if digits(anz) and int(anz) != len(st.positions):
                    findings["file(s) with ANZTEIL other than the positions (21/22/23)"] += 1
                if digits(closing[74:80]) and int(closing[74:80]) != closing_ordinal:
                    findings["file(s) with 99 SATZNR other than its position in the file"] += 1
            ph = table["phases"].get(dp)
            if not ph:
                continue
            bidder = table.get("bidderTexts", {}).get(dp)
            if st.open_bidder and (bidder == "always" or bidder == "shortForm" and not st.longform):
                phase_missing["26 TEKZ B in %s for a description with TB X" % dp] += st.open_bidder
            for za in st.seen:
                state = ph["records"].get(za)
                if records[za].get("vendor"):
                    continue
                if state is None:
                    phase_extra["%s in %s" % (za, dp)] += 1
                elif state in ("mayIfPrices", "mustIfPrices") and not st.prices:
                    phase_extra["%s in %s without prices" % (za, dp)] += 1
            for za, state in ph["records"].items():
                if za in st.seen:
                    continue
                if (state == "must" or state == "mustInLongForm" and st.longform
                        or state == "mustIfPrices" and st.prices):
                    phase_missing["%s in %s" % (za, dp)] += 1
            # per position: a 23 with FREIEMEN needs a 21 with the same OZ
            if ph["records"].get("21") == "mustIfFreeQuantity":
                if st.free_qty - st.with_21:
                    phase_missing["21 in %s for a 23 with FREIEMEN (files)" % dp] += 1
                if st.with_21 - st.free_qty - st.free_21:
                    phase_extra["21 in %s without a free quantity" % dp] += 1
    unreadable += len(walk_errors)
    print("da90-records: %d GAEB 90 file(s), %d other file(s) skipped, %d unreadable" % (files, skipped, unreadable))
    print("  phases %s" % dict(sorted(phases.items())))
    print("  editions %s" % dict(sorted(editions.items())))
    for title, counter in (("file physics (files)", phys), ("record lengths other than 80", lengths),
                           ("record types", types), ("unknown record types", unknown),
                           ("field findings", findings), ("codes outside the table", codes),
                           ("OZ masks", masks), ("records a phase does not exchange (files)", phase_extra),
                           ("required records missing", phase_missing)):
        print("  %s: %d distinct, %d in all" % (title, len(counter), sum(counter.values())))
        for k, v in sorted(counter.items(), key=lambda kv: (-kv[1], kv[0])):
            print("    %7d  %s" % (v, k))
    return unreadable


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--corpus")
    args = ap.parse_args()
    table = load()
    problems = check(table)
    for p in problems:
        print("PROBLEM " + p)
    if problems:
        print("da90-records: %d problem(s)" % len(problems))
        return 1
    if args.check or not args.corpus:
        print("da90-records: %d record type(s), %d field(s), 0 problem(s)" % (
            len(table["records"]), sum(len(fields_of(r)) for r in table["records"].values())))
    unreadable = 0
    if args.corpus and not problems:
        if not os.path.isdir(args.corpus):
            print("da90-records: the corpus folder does not exist")
            return 1
        unreadable = corpus(table, args.corpus)
    return 1 if problems or unreadable else 0


if __name__ == "__main__":
    sys.exit(main())
