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

## GAEB DA 2000

Seit 1.3 lesen `LoadFromFile` und `LoadFromStream` auch GAEB-DA-2000-Dateien der
Austauschphasen 81 bis 86 (`.P81` bis `.P86`, am Inhalt erkannt). Die Datei wird in das
Syntaxmodell GAEB DA XML 3.3 abgebildet: `Target` und `OutputTarget` sind 3.3 (2021-05) mit der
Phase der Datei, Speichern schreibt also GAEB DA XML. `Source` ist die Erkennung der Datei
(`SourceFormat` = `gfDA2000`, `Source.SourceVersion`, `Source.SourcePhase`,
`Source.SourceCharset`); ein mit `Create` angelegtes LV hat `gfUnknown`. Der Hinweis
`GAEB-BOQ-002` vermerkt das Lesen.

```pascal
Options := LandrixGaebDA2000DefaultReadOptions;
Options.Charset := gcsOem;  // der Kopf sagt ANSI, die Bytes sind OEM
Bill := TLandrixGaebBillOfQuantities.LoadFromDA2000File('angebot.p84', Options, Diags);
```

`LoadFromDA2000File` und `LoadFromDA2000Stream` nehmen Optionen (Unit
`LandrixGaebDA2000Reader`): `MaxSize` und `Charset`, das `Zeichensatz` des Kopfs übersteuert
(eine UTF-8-Bytereihenfolgemarke bedeutet immer UTF-8). Immer mit
`LandrixGaebDA2000DefaultReadOptions` beginnen.

GAEB-DA-2000-Dateien lassen die Summen der Bereiche oft aus, die X84 und X86 verlangen. Das
Laden berechnet die fehlenden mit `LandrixGaebFillMissingTotals` (Unit `LandrixGaebProcess`); ein
Angebot zählt nach den Kennzeichen seiner Datei. Eine Summe der Datei bleibt, auch wo sie
abweicht; eine `Summe`, die die Datei in unbrauchbarer Form enthält, bleibt fehlend. Die
Hinweise `GAEB-PRC-005` und `GAEB-PRC-006` melden, wie viele Summen berechnet wurden und wie
viele fehlend blieben.

Die Abbildung meldet in `Diagnostics`, wofür das Ziel kein Gegenstück hat oder was noch nicht
abgebildet ist (`GAEB-D2000-MAP-001`, je Schlüssel einmal mit Anzahl), Formatierungen, Tabellen
und Bilder in Texten (`GAEB-D2000-MAP-002`; Texte werden schlichte Absätze,
Textergänzungen bleiben) und unbrauchbare Werte (`GAEB-BR-D2000-008` und folgende). Die
Meldungen nennen Schlüssel und Zeilen, nie Werte. Was die Zielphase nicht erlaubt, bleibt im
Modell und fällt beim Speichern weg (`GAEB-WRT-001`), wie bei der Konvertierung. Fehler wie
verirrte Zeilen oder ein `#end` ohne Gegenstück werden gemeldet und übersprungen;
`ELandrixGaebError` gibt es für eine Datei, die sich nicht als Ganzes lesen lässt, eine Datei
ohne `Vergabe` und Phasen ohne XML-Gegenstück (etwa 88).

Manche Programme schreiben Formen, die GAEB DA 2000 nicht festlegt. Der Leser übernimmt die der
GAEB-Toolbox und meldet jede Art einmal als Hinweis `GAEB-D2000-MAP-008`: Textergänzungen, die
im Klartext markiert sind (`[TB01Beschriftung: [Feld] Rest]`, die Klammern als `&#91;` und
`&#93;` geschrieben), `LVGlied/Format` (`A` und `N` ergeben `Num`) und
`LVGlied/_GAEBXML_Alignment` (ergibt `Alignment`). Das Modell aus der `.P83` eines LV gleicht
dem Modell aus seiner von der GAEB-Toolbox geschriebenen `.X83` bis auf IDs, Textformatierung
und zwei Unterschiede: die Summe des LV, die X83 nicht trägt, und `LumpSumItem`, das der Leser
für die Einheit `psch` setzt.

`LandrixGaebDA2000ReadFile` (und `...Stream`, `...Buffer`) liefern nur das Syntaxmodell, wie
es abgebildet ist (keine Summen berechnet), mit der Erkennung der Datei und dem Ziel des Modells.

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
`LandrixGaebDetect`) erkennt nur Format und Ziel, auch für GAEB DA 2000 und GAEB 90. Für
GAEB DA 2000 meldet sie zusätzlich den Kopf wie gefunden: `SourceVersion` (1.0, 1.1, 1.2),
`SourcePhase` (DP, auch für Phasen ohne XML-Gegenstück) und `SourceCharset` (`Zeichensatz`);
`Target` bleibt leer, es beschreibt nur GAEB DA XML. GAEB DA 2000 lesen: siehe oben.
