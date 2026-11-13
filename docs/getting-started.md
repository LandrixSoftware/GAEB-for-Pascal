# Getting started

[Deutsch](de/getting-started.md)

GAEB-for-Pascal reads, writes, checks and converts GAEB DA XML files: bills of quantities,
bids, awards and the other exchange phases of the German construction industry. One code
base compiles with Delphi 6 through Delphi 13 and Free Pascal 3.2.2, 3.2.4 and 3.3.1
(Windows, Linux, macOS).

## Setup

1. Get the sources with the LandrixXML submodule:

   ```
   git clone --recurse-submodules https://github.com/LandrixSoftware/GAEB-for-Pascal.git
   ```

   In an existing clone: `git submodule update --init`.

2. Add two folders to the search path of your project (units and include files):

   - `source`
   - `external/landrix-xml/source`

   Delphi: *Project > Options > Delphi Compiler > Search path*. Lazarus: *Project > Project
   Options > Compiler Options > Paths > Other unit files* and *Include files*.

3. Free Pascal: compile in Delphi mode (`{$MODE DELPHI}` in the program, or `-Mdelphi`). On
   Unix, add `cwstring` as the first unit of the program if it prints texts or handles file
   names with non-ASCII characters (conversion between UTF-8 and the native string); the
   library itself does not need it.

## Two levels

| Level | Units | Use it for |
|---|---|---|
| Business facade | `LandrixGaebBoQ`, `LandrixGaebProcess` | The bill of quantities as categories, items, quantities, prices, kinds of items, parties and texts; matching, totals, building the award. |
| Syntax model | `LandrixGaebXmlModel`, `LandrixGaebXmlReader`, `LandrixGaebXmlWriter` | The document element by element, generated from the schemas: everything GAEB DA XML holds. |

The facade keeps no copy: every value is read from the syntax model and written into it.
What the reader could not take over (elements the target does not know, values that are no
valid decimal) it reports in the diagnostics; read with a `TLandrixGaebDiagnostics` to see
it. `TLandrixGaebBillOfQuantities.Document` and
`SyntaxNode` of every view lead to the syntax model when the facade does not cover something.

The stable units and the rules for later releases are listed in the README, section
*Public API*.

## Supported versions

Reading, writing and checking cover the exchange phases of the bill of quantities, DA 80 to
87 (80 to 82 bill of quantities, 83 request, 84 bid, 85 alternative bid, 86 award, 87 order
confirmation):

| Version | Edition | Read and check | Write |
|---|---|---|---|
| GAEB DA XML 3.2 | 2013-10 | DA 80 to 87 | DA 80 to 87 |
| GAEB DA XML 3.3 | 2021-05 | DA 80 to 87 | DA 80 to 87 |
| GAEB DA XML 3.3 | 2019-11 | DA 80 to 87 | no (write 2021-05) |
| GAEB DA XML 3.1 | 2009-12 | DA 81 to 87, read only (from 1.1) | no (write 3.3) |
| GAEB DA XML 3.1 | 2007-11 | DA 81 to 86, read only (from 1.1) | no (write 3.3) |
| GAEB DA XML 3.0 | 2004-07 | DA 81 to 86, read only (from 1.1) | no (write 3.3) |

GAEB DA XML 3.0 and 3.1 are read into the same model; a 3.1 file is edition 2009-12 when its
`VersDate` is 2009-12, otherwise 2007-11. They are not checked themselves (no content model check,
no XSD validation): convert them and check the output. The facade sets `OutputTarget` of such a
bill to 3.3/2021-05 of the same phase. A list directly inside a list is read into a new list item
(`GAEB-XML-009`); `Communication` in the project information has no counterpart in later versions
(`GAEB-XML-010`).

Other phases (for example time contracts, quantity determination X31, invoices X89), DP 88 and
the trade phases of 3.1, the 3.4 beta, GAEB DA 2000 and GAEB 90 are detected
(`LandrixGaebDetectFile`), not read.

A target names version, edition and exchange phase:

```pascal
LandrixGaebTarget(gv33, ge2021_05, gp83)   // request X83, GAEB DA XML 3.3
LandrixGaebTarget(gv32, ge2013_10, gp84)   // bid X84, GAEB DA XML 3.2
```

## A first program

```pascal
uses
  SysUtils, LandrixGaebTypes, LandrixGaebDiagnostics, LandrixGaebBoQ;

var
  Bill: TLandrixGaebBillOfQuantities;
  I: Integer;
begin
  Bill := TLandrixGaebBillOfQuantities.LoadFromFile('request.x83', nil, 0);
  try
    for I := 0 to Bill.AllItems.Count - 1 do
      WriteLn(string(Bill.AllItems[I].OZ), '  ', string(Bill.AllItems[I].ShortText));
  finally
    Bill.Free;
  end;
end.
```

The examples under [examples/](../examples/) are complete console programs: writing a new
bill (`WriteBoQ`), reading (`ReadBoQ`), checking (`CheckGaeb`), converting (`ConvertGaeb`)
and building an award from request and bid (`BidToAward`). `tools/build.ps1` compiles and
runs them after the tests with every Windows and Linux toolchain (not with the variants with
range checks and not on macOS).

## Strings and numbers

- Texts are `TLandrixGaebString`: UTF-16 on every compiler (`WideString` on Delphi 6 to
  2007, `string` on Delphi 2009 and later, `UnicodeString` on Free Pascal), so no character
  is lost. `LandrixXmlUtf8ToString(LandrixXmlWideToUtf8(S))` gives the native `string`.
- Quantities and prices are never `Double`. `TLandrixGaebDecimal` keeps the value exactly as
  written (coefficient and scale; `12.500` keeps three digits); functions such as
  `Item.Qty` return a copy, `SetQty` and `ClearQty` change the document. Amounts are
  computed with `LandrixXmlDecimal` and rounded commercially (half away from zero).
- Nothing depends on the locale.

## Limits and untrusted input

GAEB files from outside are untrusted. Reading rejects input larger than
`LandrixGaebDefaultMaxSize` (256 MB; the `AMaxSize` parameter sets another limit), any
document type declaration, external entities and XML that is not well-formed, with an
exception and a position, and never guesses. See [SECURITY.md](../SECURITY.md).

## Delphi 6 notes

- `TLandrixGaebString` is `WideString`: assigning it to `string` converts to the code page
  of the system; characters outside it become `?`.
- `TLandrixGaebDecimal` is an old-style `object`, records have no methods: the library uses
  only what Delphi 6 can compile, and the build checks every change with a real Delphi 6.
