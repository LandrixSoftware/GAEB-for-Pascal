#!/usr/bin/env python3
"""Writes the synthetic test cases of the business rules (plan 6.5):

  tests/data/rules/<RuleID>/valid-<n>.x83|x84      no finding of the rule
  tests/data/rules/<RuleID>/invalid-<n>.x83|x84    findings listed in expected.txt
  tests/data/rules/<RuleID>/pair-valid-<n>/first.x83, second.x84
  tests/data/rules/<RuleID>/pair-invalid-<n>/first.x83, second.x84
  tests/data/rules/<RuleID>/expected.txt           "<case> <count> <path of the first finding>"

Every document is valid GAEB DA XML 3.3 (2021-05) for its schema; the test
(tests/LandrixGaebTestRules.pas) checks that, so each case violates only the
business rule. All content is invented.

Usage:
  python tools/rules/make-rule-cases.py           write the cases
  python tools/rules/make-rule-cases.py --check   exit 1 if a file differs
"""

import importlib.util
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "tests", "data", "rules")

BOQ = "/GAEB[1]/Award[1]/BoQ[1]"
INFO = BOQ + "/BoQInfo[1]"
BODY = BOQ + "/BoQBody[1]"


def ctgy_path(*indexes):
    p = BODY
    for i in indexes:
        p += "/BoQCtgy[%d]/BoQBody[1]" % i
    return p


def item_path(n, *ctgys):
    return ctgy_path(*ctgys) + "/Itemlist[1]/Item[%d]" % n


# ---- X83 ----

def bkdn(levels=(("BoQLevel", 2, "Yes"),), item=(4, "Yes"), index=False, label_on_item=False):
    s = ""
    for t, length, num in levels:
        lbl = "<LblBoQBkdn>Titel</LblBoQBkdn>" if t == "BoQLevel" else ""
        s += "<BoQBkdn><Type>%s</Type>%s<Length>%d</Length><Num>%s</Num></BoQBkdn>" % (t, lbl, length, num)
    lbl = "<LblBoQBkdn>Pos</LblBoQBkdn>" if label_on_item else ""
    s += "<BoQBkdn><Type>Item</Type>%s<Length>%d</Length><Num>%s</Num></BoQBkdn>" % (lbl, item[0], item[1])
    if index is not False:
        s += "<BoQBkdn><Type>Index</Type><Length>%d</Length><Num>No</Num></BoQBkdn>" % (1 if index is True else index)
    return s


def text(complements=()):
    s = "<Text><p><span>Leistung</span></p></Text>"
    for n in complements:
        s += ('<TextComplement MarkLbl="%d" Kind="Bidder"><ComplBody><p><span>Erzeugnis</span></p>'
              '</ComplBody></TextComplement>' % n)
    return s


def desc83(complements=(), tsa=None, tsb=None):
    flags = ""
    if tsa:
        flags += "<ComplTSA>%s</ComplTSA>" % tsa
    if tsb:
        flags += "<ComplTSB>%s</ComplTSB>" % tsb
    return ("<Description><CompleteText>%s<DetailTxt>%s</DetailTxt><OutlineText><OutlTxt><TextOutlTxt>"
            "<p><span>Kurz</span></p></TextOutlTxt></OutlTxt></OutlineText></CompleteText></Description>"
            % (flags, text(complements)))


def item83(id_, rno, qty="10", qu="m", index=None, lump=False, tbd=False, split=None, refdescr=None,
           refrno=None, refperf=None, sumdescr=False, subdescr=False, desc=True, complements=(),
           tsa=None, tsb=None, aln=None, split_pcnt=None):
    s = '<Item ID="%s" RNoPart="%s"%s>' % (id_, rno, ' RNoIndex="%s"' % index if index else "")
    if aln:
        s += "<ALNGroupNo>%s</ALNGroupNo><ALNSerNo>%s</ALNSerNo>" % aln
    if lump:
        s += "<LumpSumItem>Yes</LumpSumItem>"
    if refdescr:
        s += "<RefDescr>%s</RefDescr>" % refdescr
    if refrno:
        s += '<RefRNo IDRef="%s"/>' % refrno
    elif refperf:
        s += '<RefPerfNo IDRef="%s"/>' % refperf
    if tbd:
        s += "<QtyTBD>Yes</QtyTBD>"
    assert qty is not None or not (split or split_pcnt), "QtySplit needs Qty"
    if qty is not None:
        s += "<Qty>%s</Qty>" % qty
        for q in split or ():
            s += "<QtySplit><Qty>%s</Qty></QtySplit>" % q
        for q in split_pcnt or ():
            s += "<QtySplit><QtyPcnt>%s</QtyPcnt></QtySplit>" % q
    s += "<QU>%s</QU>" % qu
    if desc:
        s += desc83(complements, tsa, tsb)
    if sumdescr:
        s += "<SumDescr>Yes</SumDescr>"
        if subdescr:
            s += "<SubDescr><SubDNo>1</SubDNo>%s</SubDescr>" % desc83()
    return s + "</Item>"


def markup83(id_, rno, mtype="AllInCat", subqty=None):
    s = '<MarkupItem ID="%s" RNoPart="%s"><MarkupType>%s</MarkupType>' % (id_, rno, mtype)
    if subqty:
        s += '<MarkupSubQty><RefItem IDRef="%s"/></MarkupSubQty>' % subqty
    return s + desc83() + "</MarkupItem>"


def perf83(id_, no):
    return ('<PerfDescr ID="%s"><PerfNo>%s</PerfNo><PerfLbl>Ausfuehrung</PerfLbl>%s</PerfDescr>'
            % (id_, no, desc83()))


def ctgy83(id_, rno, body):
    return ('<BoQCtgy ID="%s" RNoPart="%s"><LblTx><p><span>Titel</span></p></LblTx><BoQBody>%s</BoQBody>'
            '</BoQCtgy>' % (id_, rno, body))


def itemlist(*items):
    return "<Itemlist>%s</Itemlist>" % "".join(items)


def x83(body, breakdown=None, upcomps="", upfracdig=None):
    prj = "<NamePrj>Projekt</NamePrj>"
    if upfracdig:
        prj += "<UPFracDig>%s</UPFracDig>" % upfracdig
    return ('<?xml version="1.0" encoding="UTF-8"?>\n'
            '<GAEB xmlns="http://www.gaeb.de/GAEB_DA_XML/DA83/3.3">\n'
            '  <GAEBInfo><Version>3.3</Version><VersDate>2021-05</VersDate><Date>2026-10-23</Date>'
            '<ProgSystem>Test</ProgSystem></GAEBInfo>\n'
            '  <PrjInfo>%s</PrjInfo>\n'
            '  <Award><DP>83</DP><BoQ ID="B1"><BoQInfo><Name>LV</Name><LblBoQ>Test</LblBoQ>'
            '<OutlCompl>AllTxt</OutlCompl>%s%s</BoQInfo><BoQBody>%s</BoQBody></BoQ></Award>\n'
            '</GAEB>\n' % (prj, breakdown if breakdown is not None else bkdn(), upcomps, body))


def std83(*items):
    """Category 01 with the given items."""
    return x83(ctgy83("C1", "01", itemlist(*items)))


def upcomps(n, labels):
    s = "<NoUPComps>%d</NoUPComps>" % n
    types = ["Wages", "Materials", "Plant", "Miscellaneous", "Unknown", "Unknown"]
    for i in range(labels):
        s += '<LblUPComp%d Type="%s">Anteil %d</LblUPComp%d>' % (i + 1, types[i], i + 1, i + 1)
    return s


# ---- X84 ----

def item84(id_, rno, up="10.00", it=None, qty=None, comps=(), disc=None, notoffered=False,
           complements=None):
    s = '<Item ID="%s" RNoPart="%s">' % (id_, rno)
    if notoffered:
        s += "<NotOffered>Yes</NotOffered>"
    if qty is not None:
        s += "<Qty>%s</Qty>" % qty
    if up is not None:
        s += "<UP>%s</UP>" % up
        for i, c in enumerate(comps):
            s += "<UPComp%d>%s</UPComp%d>" % (i + 1, c, i + 1)
        if disc is not None:
            s += "<DiscountPcnt>%s</DiscountPcnt>" % disc
    if it is not None:
        s += "<IT>%s</IT>" % it
    if complements is not None:
        s += "<Description><CompleteText><DetailTxt>"
        for n in complements:
            s += ('<TextComplement MarkLbl="%s" Kind="Bidder"><ComplBody><p><span>Erzeugnis X</span></p>'
                  '</ComplBody></TextComplement>' % n)
        s += "</DetailTxt></CompleteText></Description>"
    return s + "</Item>"


def totals(total, pcnt=None, amt=None, after=None):
    s = "<Totals><Total>%s</Total>" % total
    if pcnt is not None:
        s += "<DiscountPcnt>%s</DiscountPcnt>" % pcnt
    if amt is not None:
        s += "<DiscountAmt>%s</DiscountAmt>" % amt
    if after is not None:
        s += "<TotAfterDisc>%s</TotAfterDisc>" % after
    return s + "</Totals>"


def ctgy84(id_, rno, body, tot):
    return '<BoQCtgy ID="%s" RNoPart="%s"><BoQBody>%s</BoQBody>%s</BoQCtgy>' % (id_, rno, body, tot)


def x84(body, info_totals="", breakdown=None):
    return ('<?xml version="1.0" encoding="UTF-8"?>\n'
            '<GAEB xmlns="http://www.gaeb.de/GAEB_DA_XML/DA84/3.3">\n'
            '  <GAEBInfo><Version>3.3</Version><VersDate>2021-05</VersDate><Date>2026-10-23</Date>'
            '<ProgSystem>Test</ProgSystem></GAEBInfo>\n'
            '  <PrjInfo><NamePrj>Projekt</NamePrj></PrjInfo>\n'
            '  <Award><DP>84</DP><CTR><Address><Name1>Bieter</Name1><Street>Weg 1</Street><PCode>12345</PCode>'
            '<City>Ort</City></Address></CTR><BoQ ID="B1"><BoQInfo><Name>LV</Name>%s%s</BoQInfo>'
            '<BoQBody>%s</BoQBody></BoQ></Award>\n'
            '</GAEB>\n' % (breakdown if breakdown is not None else bkdn(), info_totals, body))


def lump84(id_, rno, up, it):
    """Item of a bid for a lump sum item without quantity."""
    return '<Item ID="%s" RNoPart="%s"><UP>%s</UP><IT>%s</IT></Item>' % (id_, rno, up, it)


def std84(*items, **kw):
    """Category 01 with the given items and the given category total."""
    return x84(ctgy84("C1", "01", itemlist(*items), totals(kw.get("total", "0.00"))))


# ---- cases ----

CASES = {}


def case(rule, name, content, count=None, path=None):
    CASES.setdefault(rule, []).append((name, content, count, path))


I1 = item_path(1, 1)
I2 = item_path(2, 1)

case("GAEB-BR-OZ-001", "valid-1.x83", std83(item83("I1", "0010"), item83("I2", "0020")))
case("GAEB-BR-OZ-001", "invalid-1.x83", std83(item83("I1", "0010"), item83("I2", "0010")), 1, I2)
case("GAEB-BR-OZ-001", "invalid-2.x84", std84(item84("I1", "0010"), item84("I2", "0010")), 1, I2)
# numeric parts by value: "10" is "0010"
case("GAEB-BR-OZ-001", "invalid-3.x83", std83(item83("I1", "0010"), item83("I2", "10")), 1, I2)
# the same category OZ twice, with different items
case("GAEB-BR-OZ-001", "invalid-4.x83",
     x83(ctgy83("C1", "01", itemlist(item83("I1", "0010"))) + ctgy83("C2", "01", itemlist(item83("I2", "0020")))),
     1, BODY + "/BoQCtgy[2]")

case("GAEB-BR-OZ-002", "valid-1.x83",
     x83(ctgy83("C1", "0123456789", itemlist(item83("I1", "0010"))), bkdn(levels=(("BoQLevel", 10, "Yes"),))))
case("GAEB-BR-OZ-002", "invalid-1.x83",
     x83(ctgy83("C1", "01234567890", itemlist(item83("I1", "0010"))), bkdn(levels=(("BoQLevel", 11, "Yes"),))),
     1, I1)

case("GAEB-BR-OZ-003", "valid-1.x83", std83(item83("I1", "0010")))
case("GAEB-BR-OZ-003", "invalid-1.x83", std83(item83("I1", "00100")), 1, I1)
case("GAEB-BR-OZ-003", "invalid-2.x83",
     x83(ctgy83("C1", "01", ctgy83("C2", "01", itemlist(item83("I1", "0010"))))), 1, ctgy_path(1) + "/BoQCtgy[1]")
case("GAEB-BR-OZ-003", "invalid-3.x83", std83(item83("I1", "0010", index="A")), 1, I1)

case("GAEB-BR-OZ-004", "valid-1.x83", std83(item83("I1", "0010"), item83("I2", "20")))
case("GAEB-BR-OZ-004", "invalid-1.x83", std83(item83("I1", "0020"), item83("I2", "0010")), 1, I2)

case("GAEB-BR-OZ-005", "valid-1.x83", std83(item83("I1", "10")))
case("GAEB-BR-OZ-005", "invalid-1.x83",
     x83(ctgy83("C1", "01", itemlist(item83("I1", "A1"))), bkdn(item=(4, "No"))), 1, I1)

case("GAEB-BR-OZ-006", "valid-1.x83", std83(item83("I1", "0010")))
case("GAEB-BR-OZ-006", "invalid-1.x83", std83(item83("I1", "0000")), 1, I1)

case("GAEB-BR-BKDN-001", "valid-1.x83",
     x83(ctgy83("C1", "01", itemlist(item83("I1", "0010"))), bkdn(levels=(("BoQLevel", 2, "Yes"),), item=(12, "Yes"))))
case("GAEB-BR-BKDN-001", "invalid-1.x83",
     x83(ctgy83("C1", "01", itemlist(item83("I1", "0010"))), bkdn(levels=(("BoQLevel", 3, "Yes"),), item=(12, "Yes"))),
     1, INFO)

case("GAEB-BR-BKDN-002", "valid-1.x83",
     x83(ctgy83("C1", "1", itemlist(item83("I1", "0010"))), bkdn(levels=(("Lot", 1, "Yes"),))))
case("GAEB-BR-BKDN-002", "invalid-1.x83",
     x83(ctgy83("C1", "01", ctgy83("C2", "1", itemlist(item83("I1", "0010")))),
         bkdn(levels=(("BoQLevel", 2, "Yes"), ("Lot", 1, "Yes")))), 1, INFO)
case("GAEB-BR-BKDN-002", "invalid-2.x83",
     x83(ctgy83("C1", "1", itemlist(item83("I1", "0010"))),
         bkdn(levels=tuple(("BoQLevel", 1, "Yes") for _ in range(6)))), 1, INFO)

case("GAEB-BR-BKDN-003", "valid-1.x83", std83(item83("I1", "0010", index="A")).replace(bkdn(), bkdn(index=True)))
case("GAEB-BR-BKDN-003", "invalid-1.x83", std83(item83("I1", "0010", index="A")).replace(bkdn(), bkdn(index=2)),
     1, INFO + "/BoQBkdn[3]")

case("GAEB-BR-BKDN-004", "valid-1.x83", std83(item83("I1", "0010")))
case("GAEB-BR-BKDN-004", "invalid-1.x83", std83(item83("I1", "0010")).replace(bkdn(), bkdn(label_on_item=True)),
     1, INFO + "/BoQBkdn[2]")

case("GAEB-BR-UP-002", "valid-1.x83", x83(ctgy83("C1", "01", itemlist(item83("I1", "0010"))), upcomps=upcomps(2, 2)))
case("GAEB-BR-UP-002", "invalid-1.x83", x83(ctgy83("C1", "01", itemlist(item83("I1", "0010"))), upcomps=upcomps(3, 2)),
     1, INFO)
# two labels for NoUPComps 2, but for the components 2 and 3
case("GAEB-BR-UP-002", "invalid-3.x83",
     x83(ctgy83("C1", "01", itemlist(item83("I1", "0010"))),
         upcomps="<NoUPComps>2</NoUPComps><LblUPComp2 Type=\"Materials\">Anteil 2</LblUPComp2>"
                 "<LblUPComp3 Type=\"Plant\">Anteil 3</LblUPComp3>"), 1, INFO)
case("GAEB-BR-UP-002", "invalid-2.x83", x83(ctgy83("C1", "01", itemlist(item83("I1", "0010"))), upcomps=upcomps(2, 3)),
     1, INFO)

case("GAEB-BR-QTY-001", "valid-1.x83", std83(item83("I1", "0010", qty=None, tbd=True)))
case("GAEB-BR-QTY-002", "valid-1.x83", std83(item83("I1", "0010", qty="10", split=("4", "6"))))
# splits in percent are not added up
case("GAEB-BR-QTY-002", "valid-2.x83", std83(item83("I1", "0010", qty="10", split_pcnt=("60", "40"))))
case("GAEB-BR-QTY-002", "invalid-1.x83", std83(item83("I1", "0010", qty="10", split=("4", "5"))), 1, I1)
case("GAEB-BR-QTY-004", "valid-1.x83", std83(item83("I1", "0010", qty=None, lump=True)))
case("GAEB-BR-QTY-004", "invalid-1.x83", std83(item83("I1", "0010", qty=None)), 1, I1)
case("GAEB-BR-QTY-003", "valid-1.x83", std83(item83("I1", "0010", qty=None, tbd=True)))
case("GAEB-BR-QTY-005", "valid-1.x83", std83(item83("I1", "0010", lump=True, qty="1")))
case("GAEB-BR-QTY-005", "invalid-1.x83", std83(item83("I1", "0010", lump=True, qty=None, tbd=True)), 1, I1)
case("GAEB-BR-QTY-006", "valid-1.x83", std83(item83("I1", "0010", lump=True, qty="1.000")))
case("GAEB-BR-QTY-006", "invalid-1.x83", std83(item83("I1", "0010", lump=True, qty="2")), 1, I1)

case("GAEB-BR-ITEM-001", "valid-1.x83", std83(item83("I1", "0010")))
case("GAEB-BR-ITEM-001", "invalid-1.x83", std83(item83("I1", "0010", desc=False)), 1, I1)
case("GAEB-BR-ITEM-002", "valid-1.x83", std83(item83("I1", "0010", sumdescr=True, subdescr=True)))
case("GAEB-BR-ITEM-002", "invalid-1.x83", std83(item83("I1", "0010", sumdescr=True)), 1, I1)

case("GAEB-BR-TXT-001", "valid-1.x83",
     std83(item83("I1", "0010", refdescr="Ref"), item83("I2", "0020", refdescr="Rep", refrno="I1")))
case("GAEB-BR-TXT-001", "invalid-1.x83",
     std83(item83("I1", "0010", refdescr="Rep", refrno="I2"), item83("I2", "0020", refdescr="Rep", refrno="I1")),
     2, I1)
case("GAEB-BR-TXT-002", "valid-1.x83",
     std83(item83("I1", "0010", refdescr="Ref"), item83("I2", "0020", refdescr="Rep", refrno="I1")))
case("GAEB-BR-TXT-002", "invalid-1.x83",
     std83(item83("I1", "0010", refdescr="Ref"), item83("I2", "0020", qu="m2", refdescr="Rep", refrno="I1")), 1, I2)
case("GAEB-BR-TXT-003", "valid-1.x83",
     std83(item83("I1", "0010", refdescr="Ref"), item83("I2", "0020", refdescr="Rep", refrno="I1")))
case("GAEB-BR-TXT-003", "invalid-1.x83",
     std83(item83("I1", "0010", refdescr="Rep", refrno="I2"), item83("I2", "0020", refdescr="Ref")), 1, I1)
case("GAEB-BR-TXT-004", "valid-1.x83", std83(item83("I1", "0010", complements=(1,), tsb="Yes")))
case("GAEB-BR-TXT-004", "invalid-1.x83", std83(item83("I1", "0010", complements=(1,))), 1, I1)
# a complement in the outline text only: ComplTSA/ComplTSB concern the long text
OUTLINE_COMPL = ('<TextComplement MarkLbl="5" Kind="Bidder"><ComplBody><p><span>Erzeugnis</span></p></ComplBody>'
                 '</TextComplement>')
case("GAEB-BR-TXT-004", "valid-2.x83",
     std83(item83("I1", "0010")).replace("</TextOutlTxt></OutlTxt>", "</TextOutlTxt>" + OUTLINE_COMPL + "</OutlTxt>"))

case("GAEB-BR-PERF-001", "valid-1.x83", x83(perf83("P1", "1") + perf83("P2", "2") +
                                         ctgy83("C1", "01", itemlist(item83("I1", "0010", refperf="P1")))))
case("GAEB-BR-PERF-001", "invalid-1.x83", x83(perf83("P1", "1") + perf83("P2", "01") +
                                           ctgy83("C1", "01", itemlist(item83("I1", "0010")))),
     1, BODY + "/PerfDescr[2]")
case("GAEB-BR-PERF-002", "valid-1.x83", x83(perf83("P1", "1") +
                                         ctgy83("C1", "01", itemlist(item83("I1", "0010", refperf="P1")))))
case("GAEB-BR-PERF-002", "invalid-1.x83", x83(ctgy83("C1", "01", itemlist(item83("I1", "0010", refperf="P1"))) +
                                           perf83("P1", "1")), 1, I1)

case("GAEB-BR-MKUP-001", "valid-1.x83",
     std83(item83("I1", "0010"), markup83("M1", "0020", "ListInSubQty", "I1")))
case("GAEB-BR-MKUP-001", "invalid-1.x83",
     std83(item83("I1", "0010"), markup83("M1", "0020", "ListInSubQty")), 1, item_path(1, 1).replace("Item[1]", "MarkupItem[1]"))
case("GAEB-BR-MKUP-001", "invalid-2.x83",
     std83(item83("I1", "0010"), markup83("M1", "0020", "AllInCat", "I1")), 1, item_path(1, 1).replace("Item[1]", "MarkupItem[1]"))

case("GAEB-BR-UP-001", "valid-1.x84", std84(item84("I1", "0010", up="10.00", comps=("6.00", "4.00"))))
case("GAEB-BR-UP-001", "invalid-1.x84", std84(item84("I1", "0010", up="10.00", comps=("6.00", "3.99"))), 1, I1)
case("GAEB-BR-X84-001", "valid-1.x84", std84(item84("I1", "0010", up=None, notoffered=True)))
case("GAEB-BR-X84-001", "invalid-1.x84", std84(item84("I1", "0010", up="0.00", notoffered=True)), 1, I1)
case("GAEB-BR-SUM-001", "valid-1.x84",
     std84(item84("I1", "0010", qty="73.789", up="9.77", it="720.92"), total="720.92"))
case("GAEB-BR-SUM-001", "valid-2.x84",
     std84(item84("I1", "0010", qty="73.789", up="9.77", disc="1.5", it="710.11"), total="710.11"))
case("GAEB-BR-SUM-001", "invalid-1.x84",
     std84(item84("I1", "0010", qty="73.789", up="9.77", it="720.91"), total="720.91"), 1, I1)
case("GAEB-BR-SUM-002", "valid-1.x84",
     x84(ctgy84("C1", "01", itemlist(item84("I1", "0010", it="720.92")), totals("720.92", pcnt="1.5", after="710.11")),
         totals("710.11")))
case("GAEB-BR-SUM-002", "invalid-1.x84",
     x84(ctgy84("C1", "01", itemlist(item84("I1", "0010", it="720.92")), totals("720.92", pcnt="1.5", after="710.10")),
         totals("710.10")), 1, BODY + "/BoQCtgy[1]/Totals[1]")
case("GAEB-BR-SUM-002", "valid-2.x84",
     x84(ctgy84("C1", "01", itemlist(item84("I1", "0010", it="720.92")), totals("720.92", amt="20.92", after="700.00")),
         totals("700.00")))
case("GAEB-BR-SUM-002", "invalid-2.x84",
     x84(ctgy84("C1", "01", itemlist(item84("I1", "0010", it="720.92")), totals("720.92", amt="20.92", after="700.01")),
         totals("700.01")), 1, BODY + "/BoQCtgy[1]/Totals[1]")
# pairs: first X83, second X84
REQ = std83(item83("I1", "0010", qty="10", complements=(1,), tsb="Yes"), item83("I2", "0020", qty=None, tbd=True))


def bid(i1="", i2="", extra=""):
    return std84(i1 or item84("I1", "0010", up="2.50", it="25.00", complements=(1,)),
                 i2 or item84("I2", "0020", qty="4", up="1.00", it="4.00"), *([extra] if extra else []),
                 total="29.00")


case("GAEB-BR-PAIR-83-84-001", "pair-valid-1", (REQ, bid()))
# numeric parts by value: "10" in the bid is "0010" of the request
case("GAEB-BR-PAIR-83-84-001", "pair-valid-2",
     (REQ, bid(i1=item84("I1", "10", up="2.50", it="25.00", complements=(1,)))))
case("GAEB-BR-PAIR-83-84-001", "pair-invalid-1",
     (REQ, std84(item84("I1", "0010", up="2.50", it="25.00", complements=(1,)), total="25.00")),
     1, I2)
# a markup item of the request is an ordinary item in the bid
case("GAEB-BR-PAIR-83-84-001", "pair-invalid-3",
     (std83(item83("I1", "0010"), markup83("I2", "0020")),
      std84(item84("I1", "0010", up="2.50", it="25.00"), item84("I2", "0020", up="1.00"), total="25.00")), 1, I2)
case("GAEB-BR-PAIR-83-84-001", "pair-invalid-2", (REQ, bid(extra=item84("I3", "0030", up="1.00"))),
     1, item_path(3, 1))
case("GAEB-BR-PAIR-83-84-002", "pair-valid-1", (REQ, bid()))
case("GAEB-BR-PAIR-83-84-002", "pair-invalid-1",
     (REQ, x84(ctgy84("C1", "02", itemlist(item84("I1", "0010", up="2.50", it="25.00", complements=(1,)),
                                            item84("I2", "0020", qty="4", up="1.00", it="4.00")),
                      totals("29.00")))),
     2, BODY + "/BoQCtgy[1]")
case("GAEB-BR-PAIR-83-84-003", "pair-valid-1", (REQ.replace("<NamePrj>Projekt</NamePrj>",
                                                           "<NamePrj>Projekt</NamePrj><UPFracDig>2</UPFracDig>"), bid()))
# trailing zeros are not significant: the writer pads unit prices to the
# three digits of the schema type
case("GAEB-BR-PAIR-83-84-003", "pair-valid-2",
     (REQ.replace("<NamePrj>Projekt</NamePrj>", "<NamePrj>Projekt</NamePrj><UPFracDig>2</UPFracDig>"),
      bid(i1=item84("I1", "0010", up="2.500", it="25.00", complements=(1,)))))
case("GAEB-BR-PAIR-83-84-003", "pair-invalid-1",
     (REQ.replace("<NamePrj>Projekt</NamePrj>", "<NamePrj>Projekt</NamePrj><UPFracDig>2</UPFracDig>"),
      bid(i1=item84("I1", "0010", up="2.505", it="25.05", complements=(1,)))), 1, I1)
case("GAEB-BR-PAIR-83-84-004", "pair-valid-1", (REQ, bid()))
# a lump sum item without quantity counts with quantity 1
REQ_LUMP = std83(item83("I1", "0010", qty=None, lump=True))
case("GAEB-BR-PAIR-83-84-004", "pair-valid-2", (REQ_LUMP, std84(lump84("I1", "0010", "100.00", "100.00"), total="100.00")))
case("GAEB-BR-PAIR-83-84-004", "pair-invalid-2",
     (REQ_LUMP, std84(lump84("I1", "0010", "100.00", "250.00"), total="250.00")), 1, I1)
case("GAEB-BR-PAIR-83-84-004", "pair-invalid-1", (REQ, bid(i1=item84("I1", "0010", up="2.50", it="25.01",
                                                                       complements=(1,)))), 1, I1)
case("GAEB-BR-PAIR-83-84-005", "pair-valid-1",
     (REQ.replace("<OutlCompl>AllTxt</OutlCompl>" + bkdn(), "<OutlCompl>AllTxt</OutlCompl>" + bkdn() + upcomps(2, 2)),
      bid(i1=item84("I1", "0010", up="2.50", comps=("1.50", "1.00"), it="25.00", complements=(1,)))))
case("GAEB-BR-PAIR-83-84-005", "pair-invalid-1",
     (REQ.replace("<OutlCompl>AllTxt</OutlCompl>" + bkdn(), "<OutlCompl>AllTxt</OutlCompl>" + bkdn() + upcomps(2, 2)),
      bid(i1=item84("I1", "0010", up="2.50", comps=("1.00", "1.00", "0.50"), it="25.00", complements=(1,)))),
     1, I1)
case("GAEB-BR-PAIR-83-84-006", "pair-valid-1", (REQ, bid()))
case("GAEB-BR-PAIR-83-84-006", "pair-invalid-1",
     (REQ, bid(i1=item84("I1", "0010", qty="10", up="2.50", it="25.00", complements=(1,)))), 1, I1)
case("GAEB-BR-PAIR-83-84-007", "pair-valid-1", (REQ, bid()))
# MarkLbl is an integer: "01" is 1
# beyond the range of Integer
case("GAEB-BR-PAIR-83-84-007", "pair-valid-3",
     (std83(item83("I1", "0010", complements=(2147483648,), tsb="Yes")),
      std84(item84("I1", "0010", up="2.50", it="25.00", complements=("02147483648",)), total="25.00")))
# a description of the request made of an outline text only
REQ_OUTLINE = std83('<Item ID="I1" RNoPart="0010"><Qty>10</Qty><QU>m</QU><Description><OutlineText><OutlTxt>'
                    '<TextOutlTxt><p><span>Kurz</span></p></TextOutlTxt>%s</OutlTxt></OutlineText></Description>'
                    '</Item>' % OUTLINE_COMPL)
case("GAEB-BR-PAIR-83-84-007", "pair-valid-4",
     (REQ_OUTLINE, std84(item84("I1", "0010", up="2.50", it="25.00", complements=(5,)), total="25.00")))
case("GAEB-BR-PAIR-83-84-007", "pair-valid-2",
     (REQ, bid(i1=item84("I1", "0010", up="2.50", it="25.00", complements=("01",)))))
case("GAEB-BR-PAIR-83-84-007", "pair-invalid-1",
     (REQ, bid(i1=item84("I1", "0010", up="2.50", it="25.00", complements=(2,)))), 1, I1)

REQ_ALT = std83(item83("I1", "0010", aln=("1", "0")), item83("I2", "0020", aln=("1", "1")))


def bid_alt(ctgy_total, boq_total):
    return x84(ctgy84("C1", "01", itemlist(item84("I1", "0010", up="10.00", it="100.00"),
                                           item84("I2", "0020", up="5.00", it="50.00")),
                      totals(ctgy_total)), totals(boq_total))


case("GAEB-BR-PAIR-83-84-008", "pair-valid-1", (REQ_ALT, bid_alt("100.00", "100.00")))
case("GAEB-BR-PAIR-83-84-008", "pair-invalid-1", (REQ_ALT, bid_alt("150.00", "150.00")),
     1, BODY + "/BoQCtgy[1]/Totals[1]")
# an offered item without IT makes the sum unknown; an item not offered counts 0
case("GAEB-BR-PAIR-83-84-008", "pair-valid-2",
     (REQ, bid(i1=item84("I1", "0010", up="2.50", complements=(1,)))))
case("GAEB-BR-PAIR-83-84-008", "pair-valid-3",
     (REQ, std84(item84("I1", "0010", up=None, notoffered=True, complements=(1,)),
                 item84("I2", "0020", qty="4", up="1.00", it="4.00"), total="4.00")))
case("GAEB-BR-PAIR-83-84-008", "pair-invalid-3",
     (REQ, std84(item84("I1", "0010", up=None, notoffered=True, complements=(1,)),
                 item84("I2", "0020", qty="4", up="1.00", it="4.00"), total="5.00")),
     1, BODY + "/BoQCtgy[1]/Totals[1]")
case("GAEB-BR-PAIR-83-84-008", "pair-invalid-2", (REQ_ALT, bid_alt("100.00", "150.00")),
     1, INFO + "/Totals[1]")

# rules with a negative case that the schema already rejects: the negative
# case is a model built in the test (see LandrixGaebTestRules)
SCHEMA_GUARDED = {"GAEB-BR-QTY-001", "GAEB-BR-QTY-003"}


# ---- the same cases for the other phases of a rule ----
#
# Each rule needs a valid and an invalid case for every phase of the catalog
# (source/LandrixGaebRules.pas). Missing ones are derived from the cases of
# X83 (structure and texts) or X84 (prices): namespace and DP change, and the
# elements a phase requires (OWN, CTR, LblBoQ, OutlCompl, LblTx) or does not
# know (QU, Description, ... in X84) are added or dropped. A derived document
# must pass tools/schema/check-instance.py, else the generator stops.

ADDRESS = "<Address><Name1>Name</Name1><Street>Weg 1</Street><PCode>12345</PCode><City>Ort</City></Address>"
CATALOG = os.path.join(ROOT, "source", "LandrixGaebRules.pas")


def catalog_phases():
    text = io.open(CATALOG, encoding="ascii").read()
    result = {}
    for m in re.finditer(r"\(ID: '([^']+)';.*?Phases: \[([^\]]*)\]", text, re.S):
        result[m.group(1)] = [x.strip()[2:] for x in m.group(2).split(",") if x.strip()]
    return result


def derive(content, src, dst):
    s = content.replace("/DA%s/3.3" % src, "/DA%s/3.3" % dst).replace("<DP>%s</DP>" % src, "<DP>%s</DP>" % dst)
    if src == "84":
        # the bill of a request: labels of the bill and of categories
        s = s.replace("<BoQInfo><Name>LV</Name>", "<BoQInfo><Name>LV</Name><LblBoQ>Test</LblBoQ>"
                      "<OutlCompl>AllTxt</OutlCompl>")
        s = re.sub(r'(<BoQCtgy ID="[^"]+" RNoPart="[^"]+">)(?!<LblTx>)', r"\1<LblTx><p><span>Titel</span></p></LblTx>", s)
    if dst == "84":
        s = re.sub(r"<QU>[^<]*</QU>", "", s)
        s = re.sub(r"<LblTx>.*?</LblTx>", "", s)
        s = re.sub(r"<Description>.*?</Description>", "", s)
        s = re.sub(r"<PerfLbl>[^<]*</PerfLbl>", "", s)
        # an item of a bid has no references, kinds or quantity flags
        s = re.sub(r'<Ref(?:RNo|PerfNo) IDRef="[^"]*"/>', "", s)
        s = re.sub(r"<(RefDescr|LumpSumItem|QtyTBD)>[^<]*</\1>", "", s)
        s = s.replace("<LblBoQ>Test</LblBoQ>", "").replace("<OutlCompl>AllTxt</OutlCompl>", "")
        s = s.replace("<DP>84</DP>", "<DP>84</DP><CTR>%s</CTR>" % ADDRESS)
    if src == "83" and dst in ("84", "86"):
        # categories of a bid or an award carry totals
        s = s.replace("</BoQBody></BoQCtgy>", "</BoQBody><Totals><Total>0.00</Total></Totals></BoQCtgy>")
    if dst == "86":
        # a markup item of an award carries its amounts
        s = re.sub(r"(</MarkupType>(?:<MarkupSubQty>.*?</MarkupSubQty>)*)(<Description>)",
                   r"\1<ITMarkup>0.00</ITMarkup><Markup>0</Markup>\2", s)
        if "<CTR>" in s:
            s = s.replace("<DP>86</DP>", "<DP>86</DP><OWN>%s</OWN>" % ADDRESS)
        else:
            s = s.replace("<DP>86</DP>", "<DP>86</DP><OWN>%s</OWN><CTR>%s</CTR>" % (ADDRESS, ADDRESS))
    return s


def add_derived():
    spec = importlib.util.spec_from_file_location("check_instance",
                                                  os.path.join(ROOT, "tools", "schema", "check-instance.py"))
    checker = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(checker)
    contexts = checker.load_contexts()
    phases = catalog_phases()
    failed = []
    for rule, cases in sorted(CASES.items()):
        wanted = phases.get(rule, [])
        def kind(name):
            return "invalid" if name.startswith("invalid") else "valid"
        have = set((name[-2:], kind(name)) for name, content, count, path in cases
                   if not isinstance(content, tuple))
        phases_with_cases = set(ph for ph, k in have)
        for dst in wanted:
            missing = set(k for k in ("valid", "invalid") if (dst, k) not in have)
            if not missing:
                continue
            # X84 from X83; X81 and X86 from X83 if there is one, else from X84
            src = "83" if dst == "84" or "83" in phases_with_cases else "84"
            if src not in phases_with_cases:
                continue
            for name, content, count, path in list(cases):
                if isinstance(content, tuple) or name[-2:] != src or kind(name) not in missing:
                    continue
                derived = derive(content, src, dst)
                errors, _ = checker.check_file(contexts, io.BytesIO(derived.encode("ascii")))
                if errors:
                    failed.append("%s/%s -> x%s: %s" % (rule, name, dst, errors[0] if isinstance(errors, list)
                                                       else errors))
                    continue
                cases.append((name[:-2] + dst, derived, count, path))
    return failed


# an item that does not apply (NotAppl, award) keeps its unit price, its
# total is 0 (BVBS test files)
case("GAEB-BR-SUM-001", "valid-3.x86",
     derive(std84(item84("I1", "0010", qty="10", up="2.50", it="0.00"), total="0.00"), "84", "86")
     .replace('<Item ID="I1" RNoPart="0010">', '<Item ID="I1" RNoPart="0010"><NotAppl>Yes</NotAppl>'))


# alternatives and eventual items without total are no totals either
for ph in ("81", "86"):
    case("GAEB-BR-SUM-001", "valid-4.x" + ph,
         derive(std84(item84("I1", "0010", qty="10", up="2.50", it="0.00"), total="0.00"), "84", ph)
         .replace('<Item ID="I1" RNoPart="0010">', '<Item ID="I1" RNoPart="0010"><ALNGroupNo>1</ALNGroupNo>'
                  '<ALNSerNo>1</ALNSerNo>'))
    case("GAEB-BR-SUM-001", "valid-5.x" + ph,
         derive(std84(item84("I1", "0010", qty="10", up="2.50", it="0.00"), total="0.00"), "84", ph)
         .replace('<Item ID="I1" RNoPart="0010">', '<Item ID="I1" RNoPart="0010"><Provis>WithoutTotal</Provis>'))


# SUM-003: the totals of an X81 or X86 against its own items (the kinds are
# in the document itself)
def bill(*items, **kw):
    return std84(*items, total=kw.get("total", "29.00"))


B2 = (item84("I1", "0010", qty="10", up="2.50", it="25.00"), item84("I2", "0020", qty="4", up="1.00", it="4.00"))
for ph in ("81", "86"):
    case("GAEB-BR-SUM-003", "valid-1.x" + ph, derive(bill(*B2), "84", ph))
    case("GAEB-BR-SUM-003", "invalid-1.x" + ph, derive(bill(*B2, total="30.00"), "84", ph), 1,
         BODY + "/BoQCtgy[1]/Totals[1]")
# an alternative item does not count
case("GAEB-BR-SUM-003", "valid-2.x86",
     derive(bill(*B2, total="25.00"), "84", "86")
     .replace('<Item ID="I2" RNoPart="0020">', '<Item ID="I2" RNoPart="0020"><ALNGroupNo>1</ALNGroupNo>'
              '<ALNSerNo>1</ALNSerNo>'))
# an item that does not apply does not count
case("GAEB-BR-SUM-003", "valid-3.x86",
     derive(bill(*B2, total="25.00"), "84", "86")
     .replace('<Item ID="I2" RNoPart="0020">', '<Item ID="I2" RNoPart="0020"><NotAppl>Yes</NotAppl>'))
# Accepted: no rule for the totals, the category is not computed
case("GAEB-BR-SUM-003", "valid-4.x86",
     derive(bill(*B2, total="25.00"), "84", "86")
     .replace('<Item ID="I2" RNoPart="0020">', '<Item ID="I2" RNoPart="0020"><ALNGroupNo>1</ALNGroupNo>'
              '<ALNSerNo>1</ALNSerNo><Accepted>AltAccept</Accepted>'))

# PAIR-84-86 (warnings): the award against the bid
BID = bill(*B2)
AWARD = derive(BID, "84", "86")
case("GAEB-BR-PAIR-84-86-001", "pair-valid-1", (BID, AWARD))
case("GAEB-BR-PAIR-84-86-001", "pair-invalid-1", (BID, derive(bill(B2[0], total="25.00"), "84", "86")), 1, I2)
case("GAEB-BR-PAIR-84-86-002", "pair-valid-1", (BID, AWARD))
case("GAEB-BR-PAIR-84-86-002", "pair-invalid-1",
     (BID, derive(bill(item84("I1", "0010", qty="10", up="2.40", it="24.00"), B2[1], total="28.00"), "84", "86")),
     1, I1)
case("GAEB-BR-PAIR-84-86-003", "pair-valid-1", (BID, AWARD))
case("GAEB-BR-PAIR-84-86-003", "pair-invalid-1",
     (BID, derive(bill(item84("I1", "0010", qty="12", up="2.50", it="30.00"), B2[1], total="34.00"), "84", "86")),
     1, I1)


def pair_names(rule):
    """File names of the two documents of a pair case."""
    if "-PAIR-84-86-" in rule:
        return "first.x84", "second.x86"
    return "first.x83", "second.x84"


def files():
    result = {}
    for rule, cases in sorted(CASES.items()):
        expected = []
        for name, content, count, path in cases:
            if isinstance(content, tuple):
                first, second = pair_names(rule)
                result[os.path.join(rule, name, first)] = content[0]
                result[os.path.join(rule, name, second)] = content[1]
            else:
                result[os.path.join(rule, name)] = content
            if count is not None:
                expected.append("%s %d %s" % (name, count, path))
        result[os.path.join(rule, "expected.txt")] = "".join(line + "\n" for line in expected)
    return result


def main(argv):
    check = "--check" in argv[1:]
    status = 0
    failed = add_derived()
    if failed:
        for f in failed:
            sys.stderr.write("make-rule-cases: derived case not schema-valid: %s" % f + chr(10))
        return 1
    for rel, content in sorted(files().items()):
        path = os.path.join(OUT, rel)
        data = content.encode("ascii")
        if check:
            if not os.path.exists(path) or io.open(path, "rb").read() != data:
                sys.stderr.write("make-rule-cases: %s is not up to date\n" % rel)
                status = 1
            continue
        os.makedirs(os.path.dirname(path), exist_ok=True)
        io.open(path, "wb").write(data)
    if not check:
        print("make-rule-cases: %d file(s) in tests/data/rules" % len(files()))
    elif status == 0:
        print("make-rule-cases: cases up to date")
    return status


if __name__ == "__main__":
    sys.exit(main(sys.argv))
