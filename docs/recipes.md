# Recipes

[Deutsch](de/recipes.md)

Short answers to frequent tasks. Each recipe assumes `Diags := TLandrixGaebDiagnostics.Create`
and frees what it creates; the chapters linked at the end of a recipe explain the details.

## Which format is the file?

```pascal
Det := LandrixGaebDetectFile('input.d83', Diags, 0);
WriteLn(LandrixGaebFormatToStr(Det.Format));  // 'GAEB DA XML', 'GAEB DA 2000', 'GAEB 90'
```

The format is taken from the content, never from the extension. For GAEB DA XML `Det.Target`
holds version, edition and phase; for GAEB DA 2000 and GAEB 90 `Det.SourcePhase` and
`Det.SourceVersion`. ([Getting started](getting-started.md))

## Load any GAEB file

```pascal
Bill := TLandrixGaebBillOfQuantities.LoadFromFile('input.x83', Diags, 0);
try
  WriteLn(LandrixGaebFormatToStr(Bill.SourceFormat));
finally
  Bill.Free;
end;
```

GAEB DA XML 3.0 to 3.3, GAEB DA 2000 and GAEB 90 load into the same model (GAEB DA XML 3.3 for
the old formats). `Diags` receives what reading found. ([Reading](reading.md))

## Walk through all items

```pascal
for I := 0 to Bill.AllItems.Count - 1 do
  if Bill.AllItems[I] is TLandrixGaebItem then
  begin
    Item := TLandrixGaebItem(Bill.AllItems[I]);
    WriteLn(S(Item.OZ), ' ', S(Item.ShortText), ' ', D(Item.Qty), ' ', S(Item.QU));
  end;
```

`AllItems` holds items and markup items in document order; `Bill.Root` is the tree from the
top. `S` and `D` are the small helpers of the examples (text to native string, decimal to
text). ([Reading](reading.md#the-tree))

## Find an item by its ordinal number

```pascal
case Bill.FindItem('01.0010', '', Node) of
  gfrFound:
    if Node is TLandrixGaebItem then
      Item := TLandrixGaebItem(Node)
    else
      WriteLn('a markup item');   // TLandrixGaebMarkupItem
  gfrAmbiguous: WriteLn('the number occurs more than once');
else
  WriteLn('not found');
end;
```

The second argument is the index (`RNoIndex`), empty for none. Items and markup items share
the numbering, so the node may be either.

## Short text and long text as plain text

```pascal
WriteLn(S(Item.ShortText));
WriteLn(S(Item.LongText));   // paragraphs as lines, text complements as [mark: content]
```

The formatted text stays in the model (`Item.DetailTextNode`). ([Reading](reading.md#texts))

## Totals

```pascal
WriteLn(D(Bill.Total));                         // as the file states it
Sum := LandrixGaebComputeSum(Bill, nil, nil);   // computed from the items
if Sum.Known then
  WriteLn(LandrixXmlUtf8ToString(Sum.Value.Text));
```

A bid does not know which items count; pass a matching to its request as third argument.
`LandrixGaebFillMissingTotals` writes the totals a file leaves out. ([The bid process](process.md#totals))

## Enter prices

```pascal
Item.SetUP(Dec('12.50'));
Item.SetIT(Dec('156.25'));
```

Never go through `Double`: build a decimal from its text (`TrySetText`). The example
[CreateBid](../examples/CreateBid/CreateBid.dpr) computes `IT` exactly from quantity and unit
price. ([The bid process](process.md#creating-the-bid))

## Fill in the bidder's text complements

```pascal
for K := 0 to Item.ComplementCount - 1 do
begin
  C := Item.Complements(K);
  if C.Kind <> gckBidder then
    Continue;
  if C.WantsInteger then
    C.SetBodyNumber('2')
  else if C.WantsDecimal then
    C.SetBodyNumber('2.5')
  else
    C.SetBodyText('Product XY');
end;
```

A complement that asks for a number (`ComplBodyInt`, `ComplBodyDec`) takes only
`SetBodyNumber`; complements of sub descriptions are reached through `Item.SubDescriptions`.

## Save in another version or phase

```pascal
T := Bill.OutputTarget;
T.Version := gv32;          // a version together with its edition
T.Edition := ge2013_10;     // or only T.Phase := gp84
Bill.OutputTarget := T;
Bill.SaveToFile('output.x83', Diags);
```

What the target does not allow is refused in the default mode; `WriteOptions.Mode :=
gwmBestEffort` leaves it out and reports it (`GAEB-WRT-001`). ([Writing](writing.md))

## Check a file

```pascal
Ok := LandrixGaebXmlCheckFile('bid.x84', Diags, 0, Det);
Doc := LandrixGaebXmlReadFile('bid.x84', Diags, 0, Det);
try
  Ok := LandrixGaebCheckRules(Doc, Det.Target, Diags) and Ok;
finally
  Doc.Free;
end;
```

([Checking](checking.md))

## Convert GAEB 90 or GAEB DA 2000 to GAEB DA XML

```pascal
Bill := TLandrixGaebBillOfQuantities.LoadFromFile('request.d83', Diags, 0);
try
  Bill.SaveToFile('request.x83', Diags);
finally
  Bill.Free;
end;
```

GAEB 90 has no street, postal code and town of owner and bidder: complete them before passing
the file on. A GAEB 90 bid needs its request for the totals. The example
[LegacyToXml](../examples/LegacyToXml/LegacyToXml.dpr) shows both. ([Reading](reading.md#gaeb-90))

## Show the findings

```pascal
for I := 0 to Integer(Diags.Count) - 1 do
  WriteLn(Diags[I].RuleId, ': ', Diags[I].Message);
if Diags.HasErrors then
  WriteLn('errors found');
```

Messages name rules, paths, keys and lines, never content of the file. `Diags.ToText` gives
all of them as one text.
