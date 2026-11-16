# Kurzrezepte

[English](../recipes.md)

Kurze Antworten auf häufige Aufgaben. Jedes Rezept setzt `Diags := TLandrixGaebDiagnostics.Create`
voraus und gibt frei, was es anlegt; die am Ende eines Rezepts verlinkten Kapitel erklären die
Einzelheiten.

## Welches Format hat die Datei?

```pascal
Det := LandrixGaebDetectFile('eingabe.d83', Diags, 0);
WriteLn(LandrixGaebFormatToStr(Det.Format));  // 'GAEB DA XML', 'GAEB DA 2000', 'GAEB 90'
```

Das Format kommt aus dem Inhalt, nie aus der Dateiendung. Bei GAEB DA XML enthält `Det.Target`
Version, Ausgabe und Phase, bei GAEB DA 2000 und GAEB 90 `Det.SourcePhase` und
`Det.SourceVersion`. ([Erste Schritte](getting-started.md))

## Eine beliebige GAEB-Datei laden

```pascal
Bill := TLandrixGaebBillOfQuantities.LoadFromFile('eingabe.x83', Diags, 0);
try
  WriteLn(LandrixGaebFormatToStr(Bill.SourceFormat));
finally
  Bill.Free;
end;
```

GAEB DA XML 3.0 bis 3.3, GAEB DA 2000 und GAEB 90 landen im selben Modell (GAEB DA XML 3.3 für
die alten Formate). `Diags` erhält, was das Lesen gefunden hat. ([Lesen](reading.md))

## Alle Positionen durchlaufen

```pascal
for I := 0 to Bill.AllItems.Count - 1 do
  if Bill.AllItems[I] is TLandrixGaebItem then
  begin
    Item := TLandrixGaebItem(Bill.AllItems[I]);
    WriteLn(S(Item.OZ), ' ', S(Item.ShortText), ' ', D(Item.Qty), ' ', S(Item.QU));
  end;
```

`AllItems` enthält Positionen und Zuschlagspositionen in Dokumentreihenfolge; `Bill.Root` ist
der Baum von oben. `S` und `D` sind die kleinen Hilfsfunktionen der Beispiele (Text in nativen
String, Dezimalzahl in Text). ([Lesen](reading.md#der-baum))

## Eine Position über ihre Ordnungszahl finden

```pascal
case Bill.FindItem('01.0010', '', Node) of
  gfrFound:
    if Node is TLandrixGaebItem then
      Item := TLandrixGaebItem(Node)
    else
      WriteLn('eine Zuschlagsposition');   // TLandrixGaebMarkupItem
  gfrAmbiguous: WriteLn('die Nummer kommt mehrfach vor');
else
  WriteLn('nicht gefunden');
end;
```

Das zweite Argument ist der Index (`RNoIndex`), leer für keinen. Positionen und
Zuschlagspositionen teilen die Nummerierung, der Knoten kann also beides sein.

## Kurztext und Langtext als Klartext

```pascal
WriteLn(S(Item.ShortText));
WriteLn(S(Item.LongText));   // Absätze als Zeilen, Textergänzungen als [Marke: Inhalt]
```

Der formatierte Text bleibt im Modell (`Item.DetailTextNode`). ([Lesen](reading.md#texte))

## Summen

```pascal
WriteLn(D(Bill.Total));                         // wie die Datei sie angibt
Sum := LandrixGaebComputeSum(Bill, nil, nil);   // aus den Positionen berechnet
if Sum.Known then
  WriteLn(LandrixXmlUtf8ToString(Sum.Value.Text));
```

Ein Angebot weiß nicht, welche Positionen zählen; als drittes Argument eine Zuordnung zu seiner
Anfrage übergeben. `LandrixGaebFillMissingTotals` schreibt die Summen, die eine Datei auslässt.
([Der Vergabeprozess](process.md#summen))

## Preise eintragen

```pascal
Item.SetUP(Dec('12.50'));
Item.SetIT(Dec('156.25'));
```

Nie über `Double` gehen: eine Dezimalzahl aus ihrem Text bilden (`TrySetText`). Das Beispiel
[CreateBid](../../examples/CreateBid/CreateBid.dpr) berechnet `IT` exakt aus Menge und
Einheitspreis. ([Der Vergabeprozess](process.md#das-angebot-erstellen))

## Die Ergänzungen des Bieters ausfüllen

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
    C.SetBodyText('Fabrikat XY');
end;
```

Eine Ergänzung, die eine Zahl verlangt (`ComplBodyInt`, `ComplBodyDec`), nimmt nur
`SetBodyNumber`; die Ergänzungen von Unterbeschreibungen erreicht man über
`Item.SubDescriptions`.

## In einer anderen Version oder Phase speichern

```pascal
T := Bill.OutputTarget;
T.Version := gv32;          // eine Version zusammen mit ihrer Ausgabe
T.Edition := ge2013_10;     // oder nur T.Phase := gp84
Bill.OutputTarget := T;
Bill.SaveToFile('ausgabe.x83', Diags);
```

Was das Ziel nicht erlaubt, wird im Standardmodus verweigert; `WriteOptions.Mode :=
gwmBestEffort` lässt es weg und meldet es (`GAEB-WRT-001`). ([Schreiben](writing.md))

## Eine Datei prüfen

```pascal
Ok := LandrixGaebXmlCheckFile('angebot.x84', Diags, 0, Det);
Doc := LandrixGaebXmlReadFile('angebot.x84', Diags, 0, Det);
try
  Ok := LandrixGaebCheckRules(Doc, Det.Target, Diags) and Ok;
finally
  Doc.Free;
end;
```

([Prüfen](checking.md))

## GAEB 90 oder GAEB DA 2000 nach GAEB DA XML wandeln

```pascal
Bill := TLandrixGaebBillOfQuantities.LoadFromFile('anfrage.d83', Diags, 0);
try
  Bill.SaveToFile('anfrage.x83', Diags);
finally
  Bill.Free;
end;
```

GAEB 90 hat keine Straße, Postleitzahl und keinen Ort von Auftraggeber und Bieter: vor der
Weitergabe ergänzen. Ein Angebot in GAEB 90 braucht für die Summen seine Anfrage. Das Beispiel
[LegacyToXml](../../examples/LegacyToXml/LegacyToXml.dpr) zeigt beides. ([Lesen](reading.md#gaeb-90))

## Die Befunde ausgeben

```pascal
for I := 0 to Integer(Diags.Count) - 1 do
  WriteLn(Diags[I].RuleId, ': ', Diags[I].Message);
if Diags.HasErrors then
  WriteLn('Fehler gefunden');
```

Die Meldungen nennen Regeln, Pfade, Schlüssel und Zeilen, nie Inhalt der Datei. `Diags.ToText`
liefert alle als einen Text.
