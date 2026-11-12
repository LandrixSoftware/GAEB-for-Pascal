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
second file, the pair rules.

Stage 2 is not a general XML Schema validator: it knows exactly the schemas of the supported
targets. The reference stays the validation against the original schemas with an external
validator.

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
