# The bid process

[Deutsch](de/process.md)

The unit `LandrixGaebProcess` works on two bills of the same project: request (X83) and bid
(X84), bid and award (X86).

## Matching

```pascal
Matching := TLandrixGaebMatching.Create(Request, Bid);
try
  for I := 0 to Matching.Count - 1 do
    case Matching.Entries(I).Kind of
      gmkPair: ...       // Left and Right
      gmkOnlyLeft: ...   // in the request only
      gmkOnlyRight: ...  // in the bid only
      gmkAmbiguous: ...  // the OZ occurs more than once on one side
    else
      ;
    end;
finally
  Matching.Free;
end;
```

Categories, items and markup items are matched by ordinal number (OZ) and index, numeric
parts by value (`1.10` matches `01.0010`), the same rule as the pair rules. Remarks and
execution descriptions are not matched. `PartnerOf(Node)` gives the partner of a node of
either bill.

A matching holds views of both bills. `AddCategory`, `AddItem`, `Remove` or `Refresh` on
either bill make it stale: every method then raises `ELandrixGaebError`; create a new one.
`Bill.StructureVersion` tells a program of its own when views it keeps are no longer valid.

## Totals

A bid does not carry the kinds of items of the request (alternative, eventual item, not
applicable), so its count status is unknown. With a matching whose left side is the request,
the kinds come from there:

```pascal
Sum := LandrixGaebComputeSum(Bid, nil, Matching);   // nil: the whole bill
if Sum.Known then
  WriteLn(LandrixXmlUtf8ToString(Sum.Value.Text))
else if Sum.Blocker <> nil then
  WriteLn('unknown because of ', string(Sum.Blocker.Path))
else
  WriteLn('too large for a decimal of GAEB');
```

`LandrixGaebApplyTotals(Bill, Kinds)` writes the computed sums as `Total` of every category
and of the bill and returns the number of sums it could not compute. Computing is exact and
never rounds.

## Building the award

```pascal
Award := LandrixGaebBuildAward(Request, Bid, Diags);
try
  // the request of the example names no owner; an award needs one with an address
  Award.Owner.Name1 := 'Owner';
  Award.Owner.Street := 'Street 1';
  Award.Owner.PCode := '12345';
  Award.Owner.City := 'Town';
  Award.SaveToFile('award.x86', Diags);
finally
  Award.Free;
end;
```

The award is the request written as X86, with the prices, quantities of items with quantity
to be determined, sub descriptions, text complements of the bidder, markup items, totals and
the contractor of the bid. Elements of the bid that are not in the request
(`GAEB-PRC-001`), ambiguous OZ (`GAEB-PRC-002`), item and markup item with the same OZ
(`GAEB-PRC-003`) and markup items without markup (`GAEB-PRC-004`) are reported. The example
[BidToAward](../examples/BidToAward/BidToAward.dpr) shows the whole process.
