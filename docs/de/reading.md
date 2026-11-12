# Lesen

[English](../reading.md)

## Ein LV laden

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

`LoadFromStream` liest ab der Position eines Streams bis zu seinem Ende. Das LV besitzt das
Dokument; `Diagnostics` (darf `nil` sein) erhält die Befunde des Lesens, etwa ein Element, das das
Ziel nicht kennt (`GAEB-XML-001`).

Ausnahmen:

| Ausnahme | Wann |
|---|---|
| `ELandrixGaebError` | kein GAEB DA XML (auch XML, das in dem Teil, den die Erkennung liest, nicht wohlgeformt ist), ein Ziel, das nicht gelesen werden kann, Eingabe über der Grenze |
| `ELandrixXmlError` (Unit `LandrixXmlBase`) | XML, das sich später als nicht wohlgeformt erweist, mit Zeile und Spalte |
| `EFOpenError`, `EReadError` | Dateifehler der Laufzeitbibliothek |

## Der Baum

| Mitglied | Inhalt |
|---|---|
| `Bill.Root` | Knoten der obersten Ebene in Dokumentreihenfolge |
| `Category.Children` | Bereiche, Ausführungsbeschreibungen, Bemerkungen, Positionen und Zuschlagspositionen |
| `Bill.AllItems` | alle Positionen und Zuschlagspositionen in Dokumentreihenfolge |
| `Bill.NodeCount`, `Bill.Nodes(I)` | jeder Knoten in Dokumentreihenfolge |
| `Bill.FindCategory`, `Bill.FindItem` | ein Knoten nach Ordnungszahl (OZ), Ziffernteile nach Wert: `'1.10'` findet `'01.0010'` |

Jeder Knoten hat `Kind` (`gnkCategory`, `gnkItem`, `gnkMarkupItem`, `gnkRemark`, `gnkPerfDescr`),
`OZ` wie geschrieben, `RNoIndex`, `Parent`, `Path` (wie in Meldungen) und `SyntaxNode`. Unbekannte
Arten in einem `else`-Zweig behandeln: spätere Versionen können welche ergänzen.

Sichten gehören dem LV: nie freigeben. Sie bleiben gültig, bis sie entfernt werden, bis `Refresh`,
bis eine Strukturänderung scheitert (dann sind alle Sichten freigegeben) oder bis das LV freigegeben
wird.

## Werte

```pascal
Item := Node as TLandrixGaebItem;
if Item.Qty.HasValue then
  WriteLn(LandrixXmlUtf8ToString(Item.Qty.Text), ' ', string(Item.QU));
```

Positionen haben `Qty`, `QU`, `UP`, `UPComp(1..6)`, `DiscountPcnt`, `IT`, die Positionsarten
(`IsAlternative`, `IsBase`, `Provisional`, `IsLumpSum`, `HourIt`, `NotApplicable`, `NotOffered`,
`QtyTBD`), Unterbeschreibungen, Teilmengen, Bezüge (`RefRNo`, `RefPerfNo`, `RefBaseItem`) und
Katalogzuordnungen. Bereiche und das LV haben `Total` und den Block `Totals`; das LV hat
Auftraggeber, Auftragnehmer, Bedarfsträger, Vergabedaten, Gliederungsstufen, Lose und Losgruppen.

`CountStatus` sagt, ob ein Knoten in die Summe seines Elternknotens eingeht: `gcsCounts`,
`gcsNotCounted` (Alternative, Bedarfsposition ohne Gesamtbetrag, entfällt) oder `gcsUnknown` (ein
Angebot X84 trägt die Positionsarten der Anfrage nicht; siehe [Prozess](process.md)).

## Texte

`ShortText` und `LongText` liefern Klartext zur Anzeige. Für die Struktur (Absätze, Listen,
Tabellen, Bilder, Textergänzungen) den Text besuchen:

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
    ;  // spätere Versionen können Arten von Ereignissen ergänzen
  end;
end;

LandrixGaebVisitText(Item.DetailTextNode, Printer);
```

Textergänzungen (`Complements`) haben Nummer, Art (Auftraggeber oder Bieter), Überschrift, Inhalt
und Abschluss; ein Bieter füllt sie mit `SetBodyText` oder `SetBodyNumber`.

## Nur das Syntaxmodell

Ohne Fassade liest `LandrixGaebXmlReadFile` (Unit `LandrixGaebXmlReader`) in ein
`TLandrixGaebXmlGAEB` und liefert die Erkennung (Format, Ziel). `LandrixGaebDetectFile` (Unit
`LandrixGaebDetect`) erkennt nur Format und Ziel, auch für GAEB DA 2000 und GAEB 90.
