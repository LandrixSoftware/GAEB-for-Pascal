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
| `ELandrixGaebError` | kein GAEB DA XML, GAEB DA 2000 oder GAEB 90 (auch XML, das in dem Teil, den die Erkennung liest, nicht wohlgeformt ist), ein Ziel, das nicht gelesen werden kann, Eingabe über der Grenze |
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
`LVGlied/_GAEBXML_Alignment` (ergibt `Alignment`) und Katalogzuordnungen mit `KatNam` und
`KatBez` (je Katalog ein `BoQInfo/Ctlg`, wie bei der festgelegten Form mit `ExtDat`). Das Modell aus der `.P83` eines LV gleicht
dem Modell aus seiner von der GAEB-Toolbox geschriebenen `.X83` bis auf IDs, Textformatierung
und zwei Unterschiede: die Summe des LV, die X83 nicht trägt, und `LumpSumItem`, das der Leser
für die Einheit `psch` setzt.

### Toleranzen

Echte GAEB-DA-2000-Dateien weichen oft von den Regeln ab. Der Leser übernimmt, was eindeutig ist,
meldet es und liest weiter; abgewiesen wird eine Datei nur aus den oben genannten Gründen.
Zeilenenden CR LF, LF, CR und CR CR LF (auch gemischt) und Schlüsselwörter in beliebiger
Schreibung werden ohne Meldung gelesen. Die Meldungen nennen Schlüssel, Zeilen und Anzahlen, nie
Werte.

| Regel | Schwere | Was geschieht |
|---|---|---|
| `GAEB-BR-D2000-001` | Fehler / Hinweis | `#begin[GAEB]` nach Leerzeilen: ab dort gelesen (anderer Text davor ist keine GAEB-DA-2000-Datei); Text nach `#end[GAEB]` wird übergangen (Hinweis) |
| `GAEB-BR-D2000-002` | Fehler | verirrte Zeilen, Objekte außerhalb von `GAEB`, ein `#begin` ohne schließende Klammer und ein `#end` ohne sein Objekt werden übergangen; Objekte, die vor dem `#end` eines umgebenden Objekts nicht geschlossen sind, werden dort geschlossen und behalten ihren Inhalt |
| `GAEB-BR-D2000-004` | Hinweis | `&#...;`, das keine gültige Ersetzung ist, bleibt Text |
| `GAEB-BR-D2000-006` | Hinweis / Warnung / Fehler | `Zeichensatz` fehlt oder unbekannt: ANSI (Windows-1252); eine UTF-8-Bytereihenfolgemarke geht dem Kopf vor; `UNICODE` wird als UTF-8 gelesen; ohne Bytereihenfolgemarke werden Bytes, die kein UTF-8 sind, als ANSI gelesen (Fehler) |
| `GAEB-BR-D2000-007` | Warnung | die Zähler `m\|n` nach `#end[GAEB]` (Objekte samt `GAEB`, Elemente samt leeren) weichen von der Datei ab oder haben eine andere Form; fehlende Zähler werden nicht gemeldet |
| `GAEB-BR-D2000-014` | Hinweis | leere Elemente gelten als fehlend |
| `GAEB-BR-D2000-029` | Hinweis | Folgezeilen, die bis zur Spalte der Schlüsselklammer eingerückt sind, werden als Fortsetzung gelesen |
| `GAEB-BR-D2000-008` | Fehler | eine Zahl, die sich nicht lesen lässt, fällt weg |
| `GAEB-BR-D2000-009` | Warnung | ein Datum ohne Punkte wird als `TTMMJJJJ` gelesen, eine Uhrzeit mit Sekunden übernommen; andere Formen fallen weg |
| `GAEB-BR-D2000-010` | Warnung | `BezText` (nicht festgelegt) wird als `Bez` gelesen |
| `GAEB-BR-D2000-015` | Fehler | Teile einer Ordnungszahl, die nicht zu `LVGlied` passen, fallen weg |
| `GAEB-BR-D2000-016` | Fehler | Bereiche und Positionen auf einer Stufe |
| `GAEB-D2000-MAP-003` | Warnung | Marken von Textergänzungen ohne Gegenstück bleiben Text |
| `GAEB-D2000-MAP-004` | Warnung | Werte außerhalb der Werte von GAEB DA 2000 (Kennungen, Längen, Bereiche) fallen weg; Texte, die nur zu lang sind (Katalognamen, `TLKNr`, Textteile von `STLBBau`), bleiben |
| `GAEB-D2000-MAP-005` | Hinweis | ohne `LVGlied` wird die Gliederung aus den Ordnungszahlen abgeleitet |
| `GAEB-D2000-MAP-006` | Warnung | Steuerzeichen, die XML nicht erlaubt, werden entfernt |
| `GAEB-D2000-MAP-007` | Hinweis | Gliederungsstufen ganz ohne Wert: `Num` ist `No` für einen Index, sonst `Yes` |
| `GAEB-D2000-MAP-009` | Warnung | Strukturen ohne ihre Pflichtteile: `KatZuord`, `STLBBau`, `Mengensplit` und `Produkt` fallen weg; `AusfBeschr`, `LosGr` und `UnterBeschr` bleiben ohne die fehlenden Teile; Katalogzuordnungen in einer Datei ohne `LV` bleiben, aber kein `BoQInfo/Ctlg` legt ihre Kataloge fest |
| `GAEB-D2000-MAP-010` | Warnung | Bezüge auf eine Nummer, die die Datei nicht enthält (`BezugOZ`, `BezugAusfNr`, `ZuschlTMenge`, `LosNr`), fallen weg |

Ein `STLBBau`-Schlüssel, eine `ZuschlTMenge` oder ein `AuftrWertSchl`, deren Teile alle leer
sind, fallen ohne Meldung weg. `GAEB-D2000-MAP-001` fasst die
programmeigenen Schlüssel, die mit `_` beginnen, je Pfad zu `_*` zusammen. `Zertifikat` `N`
heißt „nicht vorhanden“ und ergibt kein `GAEBInfo/Certific`. In einem `ZusText` ist `TextRTF`
der vollständige Text (`DetailAddText`) und ein `Text` daneben der kurze (`OutlineAddText`).
`Position/Aufmass` wird noch nicht abgebildet.

`LandrixGaebDA2000ReadFile` (und `...Stream`, `...Buffer`) liefern nur das Syntaxmodell, wie
es abgebildet ist (keine Summen berechnet), mit der Erkennung der Datei und dem Ziel des Modells.

## GAEB 90

Seit 1.4 lesen `LoadFromFile` und `LoadFromStream` auch GAEB-90-Dateien der Austauschphasen 81
bis 86 (`.D81` bis `.D86`, am Inhalt erkannt: Sätze zu 80 Spalten). Wie bei GAEB DA 2000 wird
die Datei in das Syntaxmodell GAEB DA XML 3.3 abgebildet (`Target` und `OutputTarget`
3.3/2021-05 mit der Phase der Datei); `SourceFormat` ist `gfDA90`, `Source.SourcePhase` der
`DP` und `Source.SourceVersion` das `VERSDTA` des Satzes `00` wie gefunden. Der Hinweis
`GAEB-BOQ-003` vermerkt das Lesen.

```pascal
Options := LandrixGaebDA90DefaultReadOptions;
Options.Charset := gcsOem;          // die Datei ist OEM ...
Options.OemCodePage := gocCp437;    // ... in Codepage 437
Bill := TLandrixGaebBillOfQuantities.LoadFromDA90File('anfrage.d83', Options, Diags);
```

GAEB 90 gibt keinen Zeichensatz an. Standardmäßig (`Charset` = `gcsUnknown`) bedeutet eine
UTF-8-Bytereihenfolgemarke oder gültiges UTF-8 UTF-8, sonst entscheiden die Umlaute der ganzen
Datei zwischen ANSI (Windows-1252) und OEM (`OemCodePage`, Standard 850); die Wahl wird als
`GAEB-D90-FILE-001` gemeldet, `Source.SourceCharset` bleibt `gcsUnknown`. `Charset` und
`OemCodePage` übersteuern die Entscheidung (Unit `LandrixGaebDA90Reader`; immer mit
`LandrixGaebDA90DefaultReadOptions` beginnen); die Erkennung des Formats, die auf die Bytes
schaut, ändern sie nicht.

Fehlende Summen werden wie bei GAEB DA 2000 berechnet. Ein Angebot (84) zählt nach den Arten
seiner Sätze `21`; stammt eine Position aus einem `23` ohne `21`, hat sie keine Art, und die
fehlenden Summen des Angebots werden nicht berechnet (Warnung `GAEB-BOQ-004`).

Die Abbildung folgt den Sätzen: Kopfsätze `00` bis `08`, die Gliederung aus Ordnungszahlen und
`OZMASKE` (Bereiche ohne Satz `11` werden abgeleitet), Positionen, Preise, Texte mit
Textergänzungen, Unterbeschreibungen, Teilmengen, Bezüge, Ausführungsbeschreibungen,
`STLB-Bau`, Vertragsbedingungen (`T0` bis `T9`), Lose und Losgruppen (eine Stufe `Lot` über den
Stufen der Maske), Lohnänderungen, Nachlässe und Skonto. Was kein Gegenstück hat, wird je
Satzart oder Feld einmal mit Anzahl gemeldet (`GAEB-D90-MAP-001`, `-002`); die Meldungen nennen
Satzarten, Felder und Zeilen, nie Werte. `ELandrixGaebError` wird ausgelöst für Eingaben, die
kein GAEB 90 sind, eine Datei ohne Satz `00` und andere Phasen als 81 bis 86 (etwa 88).

In Teile zerlegte Dateien (`.001`, `.002`, ...) werden nicht zusammengefügt: ein späterer Teil
hat keinen Satz `00` und wird abgewiesen. Teile nur zusammenfügen, wo bekannt ist, wie sie
geschnitten wurden.

### Toleranzen

| Regel | Schwere | Was geschieht |
|---|---|---|
| `GAEB-D90-FILE-001` | Hinweis | Zeichensatz und wie er gewählt wurde |
| `GAEB-D90-FILE-002` | Warnung | Umlaute von ANSI und OEM in einer Datei |
| `GAEB-D90-FILE-003` | Hinweis | Zeilenenden LF, CR LF, CR und CR CR LF, mit `NUL NUL` verkettete Sätze, Ctrl-Z am Ende, Leerzeilen, Bytereihenfolgemarke |
| `GAEB-D90-FILE-004` | Hinweis / Warnung | Sätze kürzer (mit Leerzeichen aufgefüllt) oder länger (gekürzt) als 80 Spalten |
| `GAEB-D90-FILE-005` | Warnung | `NUL` oder Ctrl-Z in Sätzen (als Leerzeichen gelesen), Bytes, die kein gültiges UTF-8 sind |
| `GAEB-BR-D90-002` | Warnung | Satznummern fehlen oder sind nicht lückenlos |
| `GAEB-BR-D90-013` | Warnung | Vertragsbedingungen mitten im LV (als `Award/AddText` gelesen) |
| `GAEB-BR-D90-014` | Hinweis | Satzarten, die GAEB 90 nicht definiert (freier Bereich 70 bis 89, Herstellersätze), werden übersprungen |
| `GAEB-D90-MAP-004` | Warnung | Kennzeichen außerhalb der Werte von GAEB 90 |
| `GAEB-D90-MAP-008` | Warnung / Hinweis | Zahlen, die keine Ziffern sind, werden ausgelassen; Leerzeichen statt führender Nullen werden gelesen |
| `GAEB-D90-MAP-009` | Warnung | Sätze ohne den Satz, zu dem sie gehören, werden ausgelassen |
| `GAEB-D90-MAP-014` | Hinweis | Pflichtteile, für die GAEB 90 keine Quelle hat, werden gefüllt (`BoQInfo/Name`, `PrjInfo/NamePrj`, ein leeres `LblTx`); `GAEBInfo/Date` bleibt fehlend |
| `GAEB-D90-MAP-016` | Warnung | Bezüge (`28`, `35`, `45`) auf eine Nummer, die nicht in der Datei steht, werden ausgelassen |

Der Kopf der Unit `LandrixGaebDA90Mapping` nennt alle Regeln mit ihrer Schwere. Das aus der
`.D83` eines LV gelesene Modell gleicht dem aus seiner von der GAEB-Toolbox geschriebenen `.X83`,
abgesehen von IDs, Textformatierung und Abweichungen, wo GAEB 90 keine Quelle hat oder die
Toolbox eigenen Konventionen folgt: `PrjInfo/NamePrj` und `BoQInfo/Name` (gefüllt, siehe
`GAEB-D90-MAP-014`), eine Postleitzahl, die die Toolbox aus der Namenszeile des Auftraggebers nimmt, Namen
und `Num` der Gliederungsstufen, der Umsatzsteuersatz aus Satz `99` (X83 trägt keine Summen) und
`LumpSumItem` für die Einheit `psch`.
`LandrixGaebDA90ReadFile` (und `...Stream`, `...Buffer`) liefern nur das Syntaxmodell, wie es
abgebildet ist (keine Summen berechnet).

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
`SourcePhase` (DP, auch für Phasen ohne XML-Gegenstück) und `SourceCharset` (`Zeichensatz`), für
GAEB 90 `SourceVersion` (`VERSDTA`) und `SourcePhase` (`DP`) des Satzes `00`. `Target` bleibt
leer, es beschreibt nur GAEB DA XML. GAEB DA 2000 und GAEB 90 lesen: siehe oben.
