# Writing

[Deutsch](de/writing.md)

## Saving a bill

```pascal
Item.SetUP(Price);
Item.SetIT(Total);
Bill.SaveToFile('bid.x84', Diags);
```

`SaveToFile` and `SaveToStream` write the document for `Bill.OutputTarget` with
`Bill.WriteOptions`. Before writing, the output is checked against the content models of
the target; a document with errors is refused with `ELandrixGaebError`, nothing is written,
and `Diags` names every finding with its path.

## Changing values and structure

- Decimals: `SetQty`, `ClearQty`, `SetUP`, `SetIT`, ... take the value as it is; it is
  checked when writing: never rounded, a value with more significant digits than the target
  allows is refused (see `UPFracDig` below), trailing zeros beyond the digits of the target
  are dropped.
- Texts: `Category.SetLbl`; `Item.SetShortText` and `Item.SetLongText` replace the text by one
  paragraph per line, without formatting (text complements in the replaced text are lost; `''`
  removes the text); text complements of the bidder with `SetBodyText` and `SetBodyNumber`.
  Formatted texts (lists, tables, complements) go through the syntax model.
- Structure: `Bill.AddCategory`, `Bill.AddItem`, `Bill.Remove`. Other views stay valid; if
  such a change fails (memory), all views are freed as by `Refresh`. A change made directly in
  the syntax model needs `Bill.Refresh`, which frees all views.
- Parties and award data: `Bill.Owner`, `Bill.Contractor` (created on first write),
  `Bill.ContractNo`, `Bill.ContractDate`, ...

## A new document

Create a `TLandrixGaebXmlGAEB`, fill the frame (`GAEBInfo`, `PrjInfo`, `Award/BoQ/BoQInfo`
with the breakdown levels `BoQBkdn`) and wrap it in a bill; version, edition and DP are
written from the target:

```pascal
Doc := TLandrixGaebXmlGAEB.Create;
Doc.GAEBInfo.ProgSystem := 'My program';
Doc.PrjInfo.NamePrj := 'Project';
// ... BoQInfo, BoQBkdn
Bill := TLandrixGaebBillOfQuantities.Create(Doc, LandrixGaebTarget(gv33, ge2021_05, gp83), True);
Category := Bill.AddCategory(nil, '01', 'Earthwork');
Item := Bill.AddItem(Category, '0010');
```

With `True` the bill owns the document. With `False` the document must outlive the bill.
The example [WriteBoQ](../examples/WriteBoQ/WriteBoQ.dpr) is complete.

## Converting

`Bill.Target` is what the document is (read only); `Bill.OutputTarget` is what it is saved
as. A record: change a copy and assign it as a whole.

```pascal
T := Bill.Target;
T.Version := gv32;
T.Edition := ge2013_10;
Bill.OutputTarget := T;
Bill.SaveToFile('request-3.2.x83', Diags);
```

An element the target does not know is a loss (`GAEB-WRT-001`): in the default mode
`gwmNormal` the writer then refuses the document and writes nothing. With `Mode :=
gwmBestEffort` it leaves such elements out and reports them. The meaning of the document stays
with `Target`: a bid X84 saved as X86 still has unknown count status.

## Write options

Always start from `LandrixGaebXmlDefaultWriteOptions` and change single fields; later
releases may add fields. `WriteOptions` is a record property: read it into a variable,
change the variable, assign it back.

| Field | Default | Meaning |
|---|---|---|
| `Mode` | `gwmNormal` | `gwmStrict`: any warning aborts; `gwmNormal`: errors (also losses) abort; `gwmBestEffort`: findings do not abort, what the target does not allow is left out and reported (a target that cannot be written and characters XML does not allow still raise) |
| `Check` | `True` | check the output against the content models of the target |
| `PreserveScale` | `False` | write decimals with the digits they have instead of those of the target type |
| `UPFracDig` | `-1` | fraction digits of unit prices (2 or 3, from the request); a price with more significant digits is refused, never rounded |
| `Indent`, `CrLf`, `WriteBom` | `True`, `True`, `False` | layout of the file |

## Only the syntax model

`LandrixGaebXmlWriteFile`, `LandrixGaebXmlWriteStream` and `LandrixGaebXmlWriteUtf8` (unit
`LandrixGaebXmlWriter`) write a `TLandrixGaebXmlGAEB` for a target; `LandrixGaebXmlWriteCollect`
returns the output with the numbers of errors and warnings instead of raising for findings.
