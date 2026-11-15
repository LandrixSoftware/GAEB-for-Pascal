# Reading

[Deutsch](de/reading.md)

## Loading a bill

```pascal
Diags := TLandrixGaebDiagnostics.Create;
try
  Bill := TLandrixGaebBillOfQuantities.LoadFromFile('bid.x84', Diags, 0);
  try
    WriteLn(string(Bill.ProjectName));
    WriteLn(LandrixXmlUtf8ToString(LandrixGaebPhaseToDP(Bill.Target.Phase)));  // '84'
  finally
    Bill.Free;
  end;
finally
  Diags.Free;
end;
```

`LoadFromStream` reads from the position of a stream to its end. The bill owns the document;
`Diagnostics` (may be `nil`) receives the findings of reading, for example an element the
target does not know (`GAEB-XML-001`).

Exceptions:

| Exception | When |
|---|---|
| `ELandrixGaebError` | not GAEB DA XML (also XML that is not well-formed in the part the detection reads), a target that cannot be read, input larger than the limit |
| `ELandrixXmlError` (unit `LandrixXmlBase`) | XML that turns out not to be well-formed later, with line and column |
| `EFOpenError`, `EReadError` | file errors of the runtime library |

## GAEB DA 2000

Since 1.3, `LoadFromFile` and `LoadFromStream` also read GAEB DA 2000 files of the exchange
phases 81 to 86 (`.P81` to `.P86`, recognised by their content). The file is mapped into the
GAEB DA XML 3.3 syntax model: `Target` and `OutputTarget` are 3.3 (2021-05) with the phase of the
file, so saving writes GAEB DA XML. `Source` is the detection of the file (`SourceFormat` =
`gfDA2000`, `Source.SourceVersion`, `Source.SourcePhase`, `Source.SourceCharset`); a bill made
with `Create` has `gfUnknown`. The information `GAEB-BOQ-002` notes the reading.

```pascal
Options := LandrixGaebDA2000DefaultReadOptions;
Options.Charset := gcsOem;  // the header declares ANSI, the bytes are OEM
Bill := TLandrixGaebBillOfQuantities.LoadFromDA2000File('bid.p84', Options, Diags);
```

`LoadFromDA2000File` and `LoadFromDA2000Stream` take options (unit `LandrixGaebDA2000Reader`):
`MaxSize` and `Charset`, which overrides `Zeichensatz` of the header (a UTF-8 byte order mark
always means UTF-8). Always start from `LandrixGaebDA2000DefaultReadOptions`.

GAEB DA 2000 files often leave the totals of categories out, which X84 and X86 require. Loading
computes the missing ones with `LandrixGaebFillMissingTotals` (unit `LandrixGaebProcess`); a bid
counts by the kinds its file holds. A total present in the file stays, also where it differs; a
`Summe` the file holds in an unusable form stays missing. Information `GAEB-PRC-005` and
`GAEB-PRC-006` report how many totals were computed and how many stayed missing.

The mapping reports in `Diagnostics` what the target has no counterpart for or what is not
mapped yet (`GAEB-D2000-MAP-001`, once per key with a count), formatting, tables and pictures of
texts (`GAEB-D2000-MAP-002`; texts become plain paragraphs, text complements stay) and unusable
values (`GAEB-BR-D2000-008` and following). The messages name keys and lines, never values.
What the target phase does not allow stays in the model and is left out on saving
(`GAEB-WRT-001`), as with the conversion. Faults such as stray lines or an unpaired `#end` are
reported and skipped; `ELandrixGaebError` is raised for a file that cannot be read as a whole,
a file without `Vergabe` and the phases without an XML counterpart (for example 88).

Some programs write forms GAEB DA 2000 does not define. The reader takes those of the GAEB
Toolbox and reports each kind once as information `GAEB-D2000-MAP-008`: text complements
marked in plain text (`[TB01Caption: [field] tail]`, the brackets written as `&#91;` and
`&#93;`), `LVGlied/Format` (`A` and `N` give `Num`) and `LVGlied/_GAEBXML_Alignment` (gives
`Alignment`) and catalogue assignments with `KatNam` and `KatBez` (one `BoQInfo/Ctlg` per
catalogue, as for the defined form with `ExtDat`). The model read from the `.P83` of a bill equals the model read from its `.X83`
written by the GAEB Toolbox, apart from IDs, text formatting and two differences: the total of
the bill, which X83 does not carry, and `LumpSumItem`, which the reader sets for the unit `psch`.

### Tolerances

Real GAEB DA 2000 files often deviate from the rules. The reader takes what is unambiguous,
reports it and goes on; a file is rejected only for the reasons named above. Line ends CR LF,
LF, CR and CR CR LF (also mixed) and keywords in any case are read without a message. Messages
name keys, lines and counts, never values.

| Rule | Severity | What happens |
|---|---|---|
| `GAEB-BR-D2000-001` | error / information | `#begin[GAEB]` after empty lines: read from there on (other text before it is no GAEB DA 2000 file); text after `#end[GAEB]` is ignored (information) |
| `GAEB-BR-D2000-002` | error | stray lines, objects outside `GAEB`, a `#begin` without closing bracket and an `#end` without its object are ignored; objects not closed before the `#end` of an enclosing object are closed there and keep their content |
| `GAEB-BR-D2000-004` | information | `&#...;` that is no valid escape stays text |
| `GAEB-BR-D2000-006` | information / warning / error | `Zeichensatz` missing or unknown: ANSI (Windows-1252); a UTF-8 byte order mark wins over the header; `UNICODE` is read as UTF-8; without a byte order mark, bytes that are not UTF-8 are read as ANSI (error) |
| `GAEB-BR-D2000-007` | warning | the counters `m\|n` after `#end[GAEB]` (objects including `GAEB`, elements including empty ones) differ from the file or have another form; missing counters are not reported |
| `GAEB-BR-D2000-014` | information | empty elements count as missing |
| `GAEB-BR-D2000-029` | information | continuation lines indented to the column of the key's bracket are read as continuation |
| `GAEB-BR-D2000-008` | error | a number that cannot be read is left out |
| `GAEB-BR-D2000-009` | warning | a date without points is read as `TTMMJJJJ`, a time with seconds is taken; other forms are left out |
| `GAEB-BR-D2000-010` | warning | `BezText` (not defined) is read as `Bez` |
| `GAEB-BR-D2000-015` | error | parts of an ordinal number that do not fit `LVGlied` are left out |
| `GAEB-BR-D2000-016` | error | categories and items on one level |
| `GAEB-D2000-MAP-003` | warning | text complement marks that do not pair stay text |
| `GAEB-D2000-MAP-004` | warning | values outside the values of GAEB DA 2000 (codes, lengths, ranges) are left out; texts that are only too long (catalogue names, `TLKNr`, text parts of `STLBBau`) are kept |
| `GAEB-D2000-MAP-005` | information | without `LVGlied` the breakdown is derived from the ordinal numbers |
| `GAEB-D2000-MAP-006` | warning | control characters XML does not allow are removed |
| `GAEB-D2000-MAP-007` | information | breakdown levels without any value: `Num` is `No` for an index, `Yes` otherwise |
| `GAEB-D2000-MAP-009` | warning | structures without their mandatory parts: `KatZuord`, `STLBBau`, `Mengensplit` and `Produkt` are left out; `AusfBeschr`, `LosGr` and `UnterBeschr` are kept without the missing parts; catalogue assignments in a file without `LV` stay, but no `BoQInfo/Ctlg` defines their catalogues |
| `GAEB-D2000-MAP-010` | warning | references to a number not in the file (`BezugOZ`, `BezugAusfNr`, `ZuschlTMenge`, `LosNr`) are left out |

An `STLBBau` key, a `ZuschlTMenge` or an `AuftrWertSchl` whose components are all blank is
dropped without a message. `GAEB-D2000-MAP-001`
folds the program-specific keys starting with `_` into `_*` per path. `Zertifikat` `N` means
"not available" and gives no `GAEBInfo/Certific`. In a `ZusText`, `TextRTF` is the
full text (`DetailAddText`) and a `Text` next to it the short text (`OutlineAddText`).
`Position/Aufmass` is not mapped yet.

`LandrixGaebDA2000ReadFile` (and `...Stream`, `...Buffer`) return only the syntax model, as it
is mapped (no totals computed), with the detection of the file and the target of the model.

## The tree

| Member | Content |
|---|---|
| `Bill.Root` | top level nodes in document order |
| `Category.Children` | categories, execution descriptions, remarks, items and markup items |
| `Bill.AllItems` | all items and markup items in document order |
| `Bill.NodeCount`, `Bill.Nodes(I)` | every node in document order |
| `Bill.FindCategory`, `Bill.FindItem` | a node by ordinal number (OZ), numeric parts by value: `'1.10'` finds `'01.0010'` |

Every node has `Kind` (`gnkCategory`, `gnkItem`, `gnkMarkupItem`, `gnkRemark`,
`gnkPerfDescr`), `OZ` as written, `RNoIndex`, `Parent`, `Path` (as in diagnostics) and
`SyntaxNode`. Handle unknown kinds in an `else` branch: later releases may add some.

Views belong to the bill: never free them. They stay valid until they are removed, until
`Refresh`, until a structure change fails (then all views are freed) or until the bill is
freed.

## Values

```pascal
Item := Node as TLandrixGaebItem;
if Item.Qty.HasValue then
  WriteLn(LandrixXmlUtf8ToString(Item.Qty.Text), ' ', string(Item.QU));
```

Items have `Qty`, `QU`, `UP`, `UPComp(1..6)`, `DiscountPcnt`, `IT`, the kinds of items
(`IsAlternative`, `IsBase`, `Provisional`, `IsLumpSum`, `HourIt`, `NotApplicable`,
`NotOffered`, `QtyTBD`), sub descriptions, partial quantities, references (`RefRNo`,
`RefPerfNo`, `RefBaseItem`) and catalogue assignments. Categories and the bill have
`Total` and the block `Totals`; the bill has owner, contractor, requesters, award data,
breakdown levels, lots and lot groups.

`CountStatus` tells whether a node enters the total of its parent: `gcsCounts`,
`gcsNotCounted` (alternative, eventual item without total, not applicable) or `gcsUnknown`
(a bid X84 does not carry the kinds of the request; see [Process](process.md)).

## Texts

`ShortText` and `LongText` give plain text for display. For the structure (paragraphs,
lists, tables, images, text complements), visit the text:

```pascal
type
  TPrinter = class(TLandrixGaebTextVisitor)
  public
    procedure Visit(const AEvent: TLandrixGaebTextEvent); override;
  end;

procedure TPrinter.Visit(const AEvent: TLandrixGaebTextEvent);
begin
  case AEvent.Kind of
    gteText: Write(string(AEvent.Text));
    gteEndParagraph: WriteLn;
  else
    ;  // later releases may add kinds of events
  end;
end;

LandrixGaebVisitText(Item.DetailTextNode, Printer);
```

Text complements (`Complements`) have number, kind (owner or bidder), caption, body and
tail; a bidder fills them with `SetBodyText` or `SetBodyNumber`.

## Only the syntax model

Without the facade, `LandrixGaebXmlReadFile` (unit `LandrixGaebXmlReader`) reads into a
`TLandrixGaebXmlGAEB` and returns the detection (format, target). `LandrixGaebDetectFile`
(unit `LandrixGaebDetect`) only detects format and target, also for GAEB DA 2000 and GAEB 90.
For GAEB DA 2000 it also reports the header as found: `SourceVersion` (1.0, 1.1, 1.2),
`SourcePhase` (DP, also for phases without an XML counterpart) and `SourceCharset`
(`Zeichensatz`); `Target` stays empty, it describes GAEB DA XML only. Reading GAEB DA 2000:
see above.
