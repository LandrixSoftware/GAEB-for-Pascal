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
