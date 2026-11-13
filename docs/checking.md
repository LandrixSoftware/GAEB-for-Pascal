# Checking

[Deutsch](de/checking.md)

A GAEB file is checked in stages. Each stage adds findings to a `TLandrixGaebDiagnostics`;
the detection returns a record with `Accepted`, the other stages return `True` if they
found no error.

| Stage | Function | Unit | What |
|---|---|---|---|
| 1 | `LandrixGaebDetectFile` | `LandrixGaebDetect` | format, version, edition, phase from the beginning of the file; rejects input that must not be processed (size limit, document type declaration, not well-formed in the part it reads, unknown format); the whole file is checked for well-formedness by reading or by stage 2 |
| 2 | `LandrixGaebXmlCheckFile` | `LandrixGaebXmlCheck` | content models of the schema of the declared target: order and number of elements, simple types with all facets, ID and IDREF |
| 3 | `LandrixGaebCheckRules` | `LandrixGaebRules` | business rules of the phase on the syntax model |
| 4 | `LandrixGaebCheckPair` | `LandrixGaebRules` | pair rules between two documents: X83 -> X84, X84 -> X86, X86 -> X87 |

```pascal
Ok := LandrixGaebXmlCheckFile('bid.x84', Diags, 0, Det);
Doc := LandrixGaebXmlReadFile('bid.x84', Diags, 0, Det);
try
  Ok := LandrixGaebCheckRules(Doc, Det.Target, Diags) and Ok;
finally
  Doc.Free;
end;
Write(Diags.ToText);
```

The example [CheckGaeb](../examples/CheckGaeb/CheckGaeb.dpr) runs all stages and, with a
second file, the pair rules; with `-xsd=<folder>` also the validation against the original
schemas.

Stage 2 is not a general XML Schema validator: it knows exactly the schemas of the supported
targets. The reference stays the validation against the original schemas.

## Validation against the original schemas

`LandrixGaebXmlXsd` (from 1.1.0) validates against the original GAEB XSD files with the XML
Schema validator of LandrixXml. The schemas are not part of the library: download them from
gaeb.de into a folder of your own, for example with

```
pwsh tools/fetch-gaeb-xsd.ps1 -Folder C:\GAEB\Schemas
```

The script fetches the packages for GAEB DA XML 3.2 (2013-10) and 3.3 (2021-05) and checks every
file against the SHA-256 the library knows. GAEB no longer offers 3.3 edition 2019-11; copy those
schemas into the folder yourself if you need them.

```pascal
Schemas := TLandrixGaebXmlXsdSchemas.Create('C:\GAEB\Schemas');
try
  Ok := LandrixGaebXmlXsdValidateFile(Schemas, 'bid.x84', Diags, 0, Det);
  { the bill as SaveToFile would write it, before saving }
  Ok := LandrixGaebXmlXsdValidateBill(Schemas, Bill, Diags);
finally
  Schemas.Free;
end;
```

- A main schema (`GAEB_DA_XML_84_3.3_2021-05.xsd`) is searched by name anywhere below the
  folder; its Lib file must lie next to it. A main schema found twice is an error.
- A missing or unloadable schema raises `ELandrixGaebError`; `False` always means the document
  is invalid. `HasTarget` asks without loading.
- Findings are `GAEB-XSD-001` (error); the validator code (Xerces, e.g.
  `cvc-complex-type.2.4.a`) is in `XsdCode` of the diagnostic and in brackets in the message.
  Messages never quote values of the document. `GAEB-XSD-002` (warning) says that a part was
  not validated (after 1000 errors the validator stops).
- A schema file that differs from the official file is used, with the warning `GAEB-XSD-003`
  on every validation; `Verify` compares all files of the folder.
- Schema documents are only read from inside the folder (the search does not follow links); the
  folder is trusted input. A
  `TLandrixGaebXmlXsdSchemas` keeps the loaded schemas: create it once, use one per thread.

The XSD validation complements stage 2, it does not replace it: stage 2 is faster and part of
every write.

## Diagnostics

Every finding has a stable rule identifier (`RuleId`), a severity (`gsInformation`,
`gsWarning`, `gsError`, `gsFatal`), the path of the element, line and column where known,
and an English message. Messages carry no values of the bill (texts, quantities, prices);
a few name what the input declares, for example a foreign namespace, so treat logs like the
input.

| Prefix | Source |
|---|---|
| `GAEB-DET-...` | detection |
| `GAEB-XML-...` | reading |
| `GAEB-CHK-...` | content model check |
| `GAEB-WRT-...` | writing (losses, replaced values) |
| `GAEB-BR-...` | business rules and pair rules |
| `GAEB-PRC-...` | process functions |

`Diags.ToText` gives one line per finding for display; `ToWideText` keeps every character
of the paths on compilers whose `string` is not Unicode.

## The rule catalogue

`LandrixGaebRuleCount`, `LandrixGaebRuleAt(I)` and `LandrixGaebRuleIndex(ID)` list the rules
with identifier, title, severity, the phases they apply to, whether they need two documents,
and the section of the GAEB documentation they are based on. `LandrixGaebRuleSetVersion`
names the version of the rule set; it changes independently of the library version.

Errors are violations that make a document ambiguous or its amounts wrong: OZ unique and
fitting the breakdown, quantities, lump sum and quantity to be determined, unit price
components, item totals and totals of categories and the bill (computed exactly, rounded
commercially), reference descriptions, execution descriptions, markup items, and between
request and bid the items, categories, digits of unit prices, totals and text complements.
Violations of form that real exporters produce are warnings. Between bid, award and order
confirmation prices may change in negotiation, so those pair rules are warnings.
