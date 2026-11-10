#!/usr/bin/env python3
"""Writes the synthetic test documents for the findings of the old Landrix
GAEB implementation (plan, phase 1 step 8; cases 24 to 37 of the legacy
review, XML part):

  tests/data/legacy/<case>.x83|x84

Documents whose name contains "-invalid" break the schema on purpose (vendor
elements, nested categories of the old writer, broken UTF-8); all others are
valid GAEB DA XML 3.3 (2021-05), which tests/LandrixGaebTestLegacy.pas
checks. All content is invented.

Usage:
  python tools/legacy/make-legacy-cases.py           write the documents
  python tools/legacy/make-legacy-cases.py --check   exit 1 if a file differs
"""

import importlib.util
import io
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "tests", "data", "legacy")

_spec = importlib.util.spec_from_file_location("rulecases", os.path.join(ROOT, "tools", "rules", "make-rule-cases.py"))
rc = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(rc)

CASES = {}


def case(name, content):
    assert name not in CASES, name
    CASES[name] = content


def span(text):
    return "<span>%s</span>" % text


def outline(text="Kurztext"):
    return "<OutlineText><OutlTxt><TextOutlTxt><p>%s</p></TextOutlTxt></OutlTxt></OutlineText>" % span(text)


def desc(detail, outl=None, flags=""):
    return ("<Description><CompleteText>%s<DetailTxt>%s</DetailTxt>%s</CompleteText></Description>"
            % (flags, detail, outl if outl is not None else outline()))


def item83(id_, rno, inner):
    return '<Item ID="%s" RNoPart="%s">%s</Item>' % (id_, rno, inner)


def ns_root(doc, decls):
    return doc.replace('<GAEB xmlns="', '<GAEB %s xmlns="' % decls, 1)


# ---- 25: vendor namespaces (one diagnostic per namespace) ----

VENDOR_ITEMS = "".join(
    item83("I%d" % n, "%04d" % (10 * n),
           "<Qty>1.000</Qty><QU>St</QU>"
           "<NEMETSCHEK:Codetext>C%d</NEMETSCHEK:Codetext>" % n +
           ("<rib:Info>R</rib:Info>" if n == 3 else "") +
           ("<MWM:OZ>01.%04d</MWM:OZ>" % (10 * n) if n == 5 else "") +
           desc("<Text><p>%s</p></Text>" % span("Leistung")))
    for n in range(1, 21))
case("25-vendor-invalid.x83",
     ns_root(rc.std83(VENDOR_ITEMS),
             'xmlns:NEMETSCHEK="http://example.com/nemetschek" xmlns:rib="http://example.com/rib" '
             'xmlns:MWM="http://example.com/mwm"'))

# ---- 26: items above the deepest level and without category ----

BKDN3 = rc.bkdn(levels=(("BoQLevel", 2, "Yes"), ("BoQLevel", 2, "Yes")))
case("26-levels.x83",
     rc.x83(rc.ctgy83("C1", "01", rc.itemlist(rc.item83("I1", "0010"), rc.item83("I2", "0020"))) +
            rc.ctgy83("C2", "02", rc.ctgy83("C3", "01", rc.itemlist(rc.item83("I3", "0010")))),
            BKDN3))
case("26-no-category.x83",
     rc.x83(rc.itemlist(rc.item83("I1", "0010"), rc.item83("I2", "0020"))))
# the old writer nested BoQCtgy directly in BoQCtgy (without BoQBody)
case("26-nested-invalid.x84",
     rc.x84('<BoQCtgy ID="C1" RNoPart="01"><BoQCtgy ID="C2" RNoPart="01"><BoQBody>%s</BoQBody>%s</BoQCtgy>'
            '%s</BoQCtgy>' % (rc.itemlist(rc.item84("I1", "0010", up="1.00", it="10.00")), rc.totals("10.00"),
                              rc.totals("10.00")), breakdown=BKDN3))

# ---- 27: OZ parts ----

case("27-oz.x83",
     rc.x83(rc.ctgy83("C1", "A1", rc.itemlist(rc.item83("I1", "10"), rc.item83("I2", "0020", index="B"))),
            rc.bkdn(levels=(("BoQLevel", 2, "No"),), index=True)))

# ---- 28: encoding ----

case("28-bom.x83", "﻿" + rc.std83(rc.item83("I1", "0010")))
# raw ISO-8859-1 byte 0xFC in a document declared as UTF-8 (written as bytes)
case("28-latin1-invalid.x83", rc.std83(rc.item83("I1", "0010")).replace("Leistung", "Grün"))
LATIN1 = {"28-latin1-invalid.x83"}

# ---- 29: text complements ----


def complement(lbl, kind, body="", caption=False, tail=False, empty=False, dec=None, int_=None):
    s = '<TextComplement MarkLbl="%s" Kind="%s"%s>' % (lbl, kind, ' Empty="Yes"' if empty else "")
    if caption:
        s += "<ComplCaption><p>%s</p></ComplCaption>" % span("Fabrikat")
    if dec is not None:
        s += "<ComplBodyDec%s/>" % (' Value="%s"' % dec if dec else "")
    if int_ is not None:
        s += "<ComplBodyInt%s/>" % (' Value="%s"' % int_ if int_ else "")
    s += "<ComplBody>%s</ComplBody>" % (("<p>%s</p>" % span(body)) if body else "<p><span/></p>")
    if tail:
        s += "<ComplTail><p>%s</p></ComplTail>" % span("oder gleichwertig")
    return s + "</TextComplement>"


def detail29(filled):
    return ("<Text><p>%s%s%s</p>%s</Text>%s"
            % (span("Leuchte"), complement(1, "Owner", "Typ A", caption=True, tail=True), span("liefern"),
               complement(2, "Bidder", "Typ B" if filled else "", empty=not filled),
               complement(3, "Bidder", dec="12.5" if filled else "")))


def outline29(filled):
    return ("<OutlineText><OutlTxt><TextOutlTxt><p>%s</p></TextOutlTxt>%s</OutlTxt></OutlineText>"
            % (span("Leuchte"), complement(4, "Bidder", int_="7" if filled else "")))


case("29-complements.x83",
     rc.std83(item83("I1", "0010", "<Qty>4.000</Qty><QU>St</QU>" +
                     desc(detail29(False), outline29(False), "<ComplTSB>Yes</ComplTSB>"))))
# X84: paragraphs hold only text complements, a complement only its value
# and body; the outline text is not part of the bid
DETAIL29_84 = ("<Text><p>%s</p>%s</Text>%s%s"
               % (complement(1, "Owner", "Typ A"), complement(2, "Bidder", "Typ B"),
                  complement(3, "Bidder", "Typ C", dec="12.5"), complement(4, "Bidder", "Typ D", int_="7")))
case("29-complements.x84",
     rc.std84('<Item ID="I1" RNoPart="0010"><UP>2.50</UP><IT>10.00</IT><Description><CompleteText>'
              '<DetailTxt>%s</DetailTxt></CompleteText></Description></Item>' % DETAIL29_84, total="10.00"))

# ---- 30: formatted text ----

IMAGE = "iVBORw0KGgo="
FORMAT = ("<Text>"
          "<p>%s<br/><br/><br/>%s</p>"
          "<p><span/></p>"
          "<div>%s</div>"
          "<ul><li>%s</li><li><p>%s</p></li></ul>"
          '<ol start="3"><li>%s</li></ol>'
          "<table><tr><th><span>Spalte</span></th></tr><tr><td>%s</td></tr></table>"
          '<p><image Type="image/png">%s</image></p>'
          '<Image Type="image/png" Name="bild.png">%s</Image>'
          "<page/>"
          "<p>%s</p>"
          "</Text>"
          % (span("Zeile 1"), span("Zeile 2"), span("Block"), span("Punkt a"), span("Punkt b"), span("Schritt 3"),
             span("Zelle"), IMAGE, IMAGE, span("Ende")))
case("30-format.x83", rc.std83(item83("I1", "0010", "<Qty>1.000</Qty><QU>St</QU>" + desc(FORMAT))))

# ---- 31 and 35: element list of X83 and X84 ----

def ctlg_assign(code):
    return "<CtlgAssign><CtlgID>C1</CtlgID><CtlgCode>%s</CtlgCode></CtlgAssign>" % code


UPCOMPS3 = ('<NoUPComps>3</NoUPComps><LblUPComp1 Type="Wages">Lohn</LblUPComp1>'
            '<LblUPComp2 Type="Materials">Stoffe</LblUPComp2><LblUPComp3 Type="Plant">Geraete</LblUPComp3>')
D = desc("<Text><p>%s</p></Text>" % span("Leistung"))
ITEMS31 = rc.itemlist(
    item83("I1", "0010", "<ALNGroupNo>1</ALNGroupNo><ALNSerNo>0</ALNSerNo><Qty>10.000</Qty><QU>m</QU>" + D),
    item83("I2", "0020", "<ALNGroupNo>1</ALNGroupNo><ALNSerNo>1</ALNSerNo><Qty>10.000</Qty><QU>m</QU>" + D),
    item83("I3", "0030", "<Provis>WithoutTotal</Provis><Qty>2.000</Qty><QU>St</QU>" + D),
    item83("I4", "0040", "<LumpSumItem>Yes</LumpSumItem><QU>psch</QU>" + D),
    item83("I5", "0050", "<HourIt>Yes</HourIt><Qty>8.000</Qty><QU>h</QU>" + D),
    item83("I6", "0060", "<RefDescr>Ref</RefDescr><Qty>3.000</Qty><QU>m2</QU>" + D),
    item83("I7", "0070", '<RefDescr>Rep</RefDescr><RefRNo IDRef="I6"/><Qty>5.000</Qty><QU>m2</QU>' + D),
    item83("I8", "0080", '<RefPerfNo IDRef="P1"/><QtyTBD>Yes</QtyTBD><QU>m3</QU>' + D),
    # 3.2 requires a catalogue assignment in QtySplit, 3.3 does not
    item83("I9", "0090", "<Qty>10.000</Qty><QtySplit><Qty>4.000</Qty>%s</QtySplit><QtySplit><Qty>6.000</Qty>%s"
                         "</QtySplit><QU>t</QU><VAT>19.00</VAT>" % (ctlg_assign("KS1"), ctlg_assign("KS2")) + D),
    item83("I10", "0100", "<Qty>1.000</Qty><QU>St</QU>" + D +
           "<SumDescr>Yes</SumDescr><SubDescr><SubDNo>1</SubDNo>%s<Qty>2.000</Qty><QU>St</QU></SubDescr>" % D),
    '<MarkupItem ID="M1" RNoPart="0110"><MarkupType>AllInCat</MarkupType>%s</MarkupItem>' % D,
    '<MarkupItem ID="M2" RNoPart="0120"><MarkupType>IdentAsMark</MarkupType>%s</MarkupItem>' % D,
    '<MarkupItem ID="M3" RNoPart="0130"><MarkupType>ListInSubQty</MarkupType><MarkupSubQty><RefItem IDRef="I1"/>'
    '</MarkupSubQty>%s</MarkupItem>' % D)
PERF = ('<PerfDescr ID="P1"><PerfNo>1</PerfNo><PerfLbl>Ausfuehrung</PerfLbl>%s</PerfDescr>' % rc.desc83())
X83_31 = rc.x83(PERF + rc.ctgy83("C1", "01", ITEMS31) +
                '<BoQCtgy ID="C2" RNoPart="02"><LblTx><p><span>Entfaellt</span></p></LblTx>'
                '<NotApplBoQ>Yes</NotApplBoQ><BoQBody>%s</BoQBody></BoQCtgy>'
                % rc.itemlist(rc.item83("I11", "0010")),
                upcomps=UPCOMPS3 + "<Ctlg><CtlgID>C1</CtlgID><CtlgType>cost unit</CtlgType>"
                                   "<CtlgName>Kostentraeger</CtlgName></Ctlg>", upfracdig="3")
X83_31 = X83_31.replace("<Award><DP>83</DP>",
                        "<Award><DP>83</DP><AwardInfo><Cur>EUR</Cur><CurLbl>Euro</CurLbl></AwardInfo>"
                        "<AddText><DetailAddText><p>%s</p></DetailAddText></AddText>" % span("Vorbemerkung"))
case("31-elements.x83", X83_31)

ITEMS31_84 = rc.itemlist(
    '<Item ID="I1" RNoPart="0010"><UP>12.345</UP><UPComp1>10.000</UPComp1><UPComp2>2.345</UPComp2>'
    '<DiscountPcnt>2.000</DiscountPcnt><IT>120.98</IT><VAT>19.00</VAT></Item>',
    '<Item ID="I2" RNoPart="0020"><UP>5.000</UP><IT>50.00</IT></Item>',
    '<Item ID="I3" RNoPart="0030"><UP>1.000</UP><IT>2.00</IT></Item>',
    '<Item ID="I4" RNoPart="0040"><UP>300.000</UP><IT>300.00</IT></Item>',
    '<Item ID="I5" RNoPart="0050"><NotOffered>Yes</NotOffered></Item>',
    '<Item ID="I6" RNoPart="0060"><UP>0.000</UP><IT>0.00</IT></Item>',
    '<Item ID="I7" RNoPart="0070"><UP>4.000</UP><IT>20.00</IT></Item>',
    '<Item ID="I8" RNoPart="0080"><Qty>2.500</Qty><UP>10.000</UP><IT>25.00</IT></Item>',
    '<Item ID="I9" RNoPart="0090"><UP>1.000</UP><IT>10.00</IT></Item>',
    '<Item ID="I10" RNoPart="0100"><UP>1.000</UP><IT>1.00</IT><SubDescr><SubDNo>1</SubDNo><UP>0.500</UP>'
    '</SubDescr></Item>',
    '<MarkupItem ID="M1" RNoPart="0110"><Markup>5.000</Markup><IT>23.85</IT></MarkupItem>',
    '<MarkupItem ID="M2" RNoPart="0120"><ITMarkup>10.00</ITMarkup><IT>10.00</IT></MarkupItem>',
    '<MarkupItem ID="M3" RNoPart="0130"><Markup>1.000</Markup><IT>1.21</IT></MarkupItem>')
# counting: I1 120.98, I4 300.00, I5 0, I6 0, I7 20.00, I8 25.00, I9 10.00, I10 1.00, M1-M3 35.06
# (I2 alternative, I3 eventual without total)
X84_31 = rc.x84(rc.ctgy84("C1", "01", ITEMS31_84, rc.totals("512.04", pcnt="1.000", after="506.92")) +
                '<BoQCtgy ID="C2" RNoPart="02"><BoQBody>%s</BoQBody>%s</BoQCtgy>'
                % (rc.itemlist('<Item ID="I11" RNoPart="0010"><UP>1.000</UP><IT>10.00</IT></Item>'),
                   rc.totals("10.00")),
                rc.totals("506.92"))
case("31-elements.x84", X84_31)

# ---- 34: 0.00 is a value, an absent price is none ----

case("34-zero.x84",
     rc.std84('<Item ID="I1" RNoPart="0010"><UP>0.00</UP><IT>0.00</IT></Item>',
              '<Item ID="I2" RNoPart="0020"><NotOffered>Yes</NotOffered></Item>', total="0.00"))


def files():
    return dict(CASES)


def main(argv):
    check = "--check" in argv[1:]
    status = 0
    for name, content in sorted(files().items()):
        path = os.path.join(OUT, name)
        data = content.encode("latin-1" if name in LATIN1 else "utf-8")
        if check:
            if not os.path.exists(path) or io.open(path, "rb").read() != data:
                sys.stderr.write("make-legacy-cases: %s is not up to date\n" % name)
                status = 1
            continue
        if not os.path.isdir(OUT):
            os.makedirs(OUT)
        io.open(path, "wb").write(data)
    if not check:
        print("make-legacy-cases: %d file(s) in tests/data/legacy" % len(files()))
    elif status == 0:
        print("make-legacy-cases: documents up to date")
    return status


if __name__ == "__main__":
    sys.exit(main(sys.argv))
