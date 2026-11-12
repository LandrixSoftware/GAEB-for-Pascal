# Schreiben

[English](../writing.md)

## Ein LV speichern

```pascal
Item.SetUP(Price);
Item.SetIT(Total);
Bill.SaveToFile('bid.x84', Diags);
```

`SaveToFile` und `SaveToStream` schreiben das Dokument für `Bill.OutputTarget` mit
`Bill.WriteOptions`. Vor dem Schreiben wird die Ausgabe gegen die Inhaltsmodelle des Ziels
geprüft; ein Dokument mit Fehlern wird mit `ELandrixGaebError` abgelehnt, nichts wird geschrieben,
und `Diags` nennt jeden Befund mit seinem Pfad.

## Werte und Struktur ändern

- Dezimalwerte: `SetQty`, `ClearQty`, `SetUP`, `SetIT`, ... übernehmen den Wert, wie er ist; er
  wird beim Schreiben geprüft: nie gerundet, ein Wert mit mehr werttragenden Stellen, als das Ziel
  erlaubt, wird abgelehnt (siehe `UPFracDig` unten), Nullen am Ende über die Stellen des Ziels
  hinaus entfallen.
- Texte: `Category.SetLbl`; `Item.SetShortText` und `Item.SetLongText` ersetzen den Text durch einen
  Absatz je Zeile, ohne Formatierung (Textergänzungen im ersetzten Text gehen verloren; `''` entfernt
  den Text); Textergänzungen des Bieters mit `SetBodyText` und `SetBodyNumber`. Formatierte Texte
  (Listen, Tabellen, Ergänzungen) gehen über das Syntaxmodell.
- Struktur: `Bill.AddCategory`, `Bill.AddItem`, `Bill.Remove`. Andere Sichten bleiben gültig;
  scheitert eine solche Änderung (Speicher), sind wie nach `Refresh` alle Sichten freigegeben. Eine
  Änderung direkt im Syntaxmodell braucht `Bill.Refresh`, das alle Sichten freigibt.
- Parteien und Vergabedaten: `Bill.Owner`, `Bill.Contractor` (beim ersten Schreiben angelegt),
  `Bill.ContractNo`, `Bill.ContractDate`, ...

## Ein neues Dokument

Ein `TLandrixGaebXmlGAEB` anlegen, den Rahmen füllen (`GAEBInfo`, `PrjInfo`, `Award/BoQ/BoQInfo`
mit den Gliederungsstufen `BoQBkdn`) und in ein LV einhüllen; Version, Ausgabe und DP werden aus dem
Ziel geschrieben:

```pascal
Doc := TLandrixGaebXmlGAEB.Create;
Doc.GAEBInfo.ProgSystem := 'Mein Programm';
Doc.PrjInfo.NamePrj := 'Projekt';
// ... BoQInfo, BoQBkdn
Bill := TLandrixGaebBillOfQuantities.Create(Doc, LandrixGaebTarget(gv33, ge2021_05, gp83), True);
Category := Bill.AddCategory(nil, '01', 'Erdarbeiten');
Item := Bill.AddItem(Category, '0010');
```

Mit `True` besitzt das LV das Dokument. Mit `False` muss das Dokument das LV überleben. Das
Beispiel [WriteBoQ](../../examples/WriteBoQ/WriteBoQ.dpr) ist vollständig.

## Konvertieren

`Bill.Target` ist, was das Dokument ist (nur lesbar); `Bill.OutputTarget` ist, als was es
gespeichert wird. Ein Record: eine Kopie ändern und als Ganzes zuweisen.

```pascal
T := Bill.Target;
T.Version := gv32;
T.Edition := ge2013_10;
Bill.OutputTarget := T;
Bill.SaveToFile('request-3.2.x83', Diags);
```

Ein Element, das das Ziel nicht kennt, ist ein Verlust (`GAEB-WRT-001`): im Standardmodus
`gwmNormal` lehnt der Schreiber das Dokument dann ab und schreibt nichts. Mit `Mode :=
gwmBestEffort` lässt er solche Elemente weg und meldet sie. Die Bedeutung des Dokuments bleibt bei
`Target`: ein Angebot X84, das als X86 gespeichert wird, hat weiter unbestimmten Zählstatus.

## Schreiboptionen

Immer mit `LandrixGaebXmlDefaultWriteOptions` beginnen und einzelne Felder ändern; spätere Versionen
können Felder ergänzen. `WriteOptions` ist eine Record-Eigenschaft: in eine Variable lesen, die
Variable ändern, zurückzuweisen.

| Feld | Standard | Bedeutung |
|---|---|---|
| `Mode` | `gwmNormal` | `gwmStrict`: jede Warnung bricht ab; `gwmNormal`: Fehler (auch Verluste) brechen ab; `gwmBestEffort`: Befunde brechen nicht ab, was das Ziel nicht erlaubt, wird weggelassen und gemeldet (ein Ziel, das nicht geschrieben werden kann, und Zeichen, die XML nicht erlaubt, lösen weiter eine Ausnahme aus) |
| `Check` | `True` | die Ausgabe gegen die Inhaltsmodelle des Ziels prüfen |
| `PreserveScale` | `False` | Dezimalwerte mit ihren Stellen statt mit denen des Zieltyps schreiben |
| `UPFracDig` | `-1` | Nachkommastellen der Einheitspreise (2 oder 3, aus der Anfrage); ein Preis mit mehr werttragenden Stellen wird abgelehnt, nie gerundet |
| `Indent`, `CrLf`, `WriteBom` | `True`, `True`, `False` | Gestalt der Datei |

## Nur das Syntaxmodell

`LandrixGaebXmlWriteFile`, `LandrixGaebXmlWriteStream` und `LandrixGaebXmlWriteUtf8` (Unit
`LandrixGaebXmlWriter`) schreiben ein `TLandrixGaebXmlGAEB` für ein Ziel;
`LandrixGaebXmlWriteCollect` liefert die Ausgabe mit der Zahl der Fehler und Warnungen, statt für
Befunde eine Ausnahme auszulösen.
