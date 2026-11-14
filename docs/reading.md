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
