# Der Vergabeprozess

[English](../process.md)

Die Unit `LandrixGaebProcess` arbeitet auf zwei LV desselben Projekts: Anfrage (X83) und Angebot
(X84), Angebot und Auftrag (X86).

## Das Angebot erstellen

Der Bieter lädt die Anfrage, bepreist ihre Positionen und speichert sie als Angebot; das
Beispiel [CreateBid](../../examples/CreateBid/CreateBid.dpr) zeigt es vollständig.

```pascal
Bill := TLandrixGaebBillOfQuantities.LoadFromFile('anfrage.x83', Diags, 0);  // auch GAEB 90, GAEB DA 2000
T := Bill.OutputTarget;                // 3.3 auch für eine aus 3.0/3.1 gelesene Anfrage
T.Phase := gp84;
Bill.OutputTarget := T;                // als Angebot gespeichert, das Dokument bleibt Anfrage
Options := Bill.WriteOptions;
Options.Mode := gwmBestEffort;         // ein Angebot lässt Texte, Einheiten, Bezeichnungen weg (GAEB-WRT-001)
Bill.WriteOptions := Options;
Bill.Contractor.Name1 := 'Bau GmbH';         // die X84 braucht die volle Anschrift
Bill.Contractor.Street := 'Hauptstr. 2';
Bill.Contractor.PCode := '12345';
Bill.Contractor.City := 'Musterstadt';
Item.SetUP(EP);                        // für jede Position
Item.SetIT(Betrag);                    // Menge x EP, halb weg von null auf Cent gerundet
if not Item.QtyTBD then
  Item.ClearQty;                       // ein Angebot nennt nur die offen gelassenen Mengen
LandrixGaebApplyTotals(Bill, nil);     // Summen der Bereiche und des LV
Bill.SaveToFile('angebot.x84', Diags);
```

Die Ergänzungen des Bieters werden mit `SetBodyText` oder `SetBodyNumber` gefüllt. Weil das
Dokument eine Anfrage bleibt, sind die Arten seiner Positionen (Alternativen,
Bedarfspositionen) bekannt und entscheiden, was zählt. `CheckGaeb anfrage.x83 angebot.x84`
prüft das Ergebnis mit den Paarregeln.

## Zuordnung

```pascal
Matching := TLandrixGaebMatching.Create(Request, Bid);
try
  for I := 0 to Matching.Count - 1 do
    case Matching.Entries(I).Kind of
      gmkPair: ...       // Left und Right
      gmkOnlyLeft: ...   // nur in der Anfrage
      gmkOnlyRight: ...  // nur im Angebot
      gmkAmbiguous: ...  // die OZ kommt auf einer Seite mehrfach vor
    else
      ;
    end;
finally
  Matching.Free;
end;
```

Bereiche, Positionen und Zuschlagspositionen werden über Ordnungszahl (OZ) und Index zugeordnet,
Ziffernteile nach Wert (`1.10` passt zu `01.0010`), nach derselben Regel wie die Paarregeln.
Bemerkungen und Ausführungsbeschreibungen werden nicht zugeordnet. `PartnerOf(Node)` liefert den
Partner eines Knotens eines der beiden LV.

Eine Zuordnung hält Sichten beider LV. `AddCategory`, `AddItem`, `Remove` oder `Refresh` an einem
der beiden machen sie ungültig: jede Methode löst dann `ELandrixGaebError` aus; eine neue anlegen.
`Bill.StructureVersion` sagt einem eigenen Programm, wann Sichten, die es hält, nicht mehr gültig
sind.

## Summen

Ein Angebot trägt die Positionsarten der Anfrage nicht (Alternative, Bedarfsposition, entfällt),
sein Zählstatus ist daher unbestimmt. Mit einer Zuordnung, deren linke Seite die Anfrage ist,
kommen die Arten von dort:

```pascal
Sum := LandrixGaebComputeSum(Bid, nil, Matching);   // nil: das ganze LV
if Sum.Known then
  WriteLn(LandrixXmlUtf8ToString(Sum.Value.Text))
else if Sum.Blocker <> nil then
  WriteLn('unbekannt wegen ', string(Sum.Blocker.Path))
else
  WriteLn('zu gross fuer eine Dezimalzahl von GAEB');
```

`LandrixGaebApplyTotals(Bill, Kinds)` schreibt die berechneten Summen als `Total` jedes Bereichs und
des LV und liefert die Zahl der Summen, die sich nicht berechnen ließen. Gerechnet wird exakt und
nie gerundet. `LandrixGaebFillMissingTotals(Bill, Kinds, Diags)` (seit 1.3) schreibt nur die fehlenden
Summen und lässt die anderen stehen; es liefert die Zahl der geschriebenen und meldet sie als
`GAEB-PRC-005`, die fehlend gebliebenen als `GAEB-PRC-006`. Ein X83 hat keine Summen und bleibt
unverändert. Das Laden einer GAEB-DA-2000- oder GAEB-90-Datei ruft es auf.

## Den Auftrag zusammensetzen

```pascal
Award := LandrixGaebBuildAward(Request, Bid, Diags);
try
  // die Anfrage des Beispiels nennt keinen Auftraggeber; ein Auftrag braucht einen mit Anschrift
  Award.Owner.Name1 := 'Auftraggeber';
  Award.Owner.Street := 'Weg 1';
  Award.Owner.PCode := '12345';
  Award.Owner.City := 'Ort';
  Award.SaveToFile('award.x86', Diags);
finally
  Award.Free;
end;
```

Der Auftrag ist die Anfrage als X86, mit den Preisen, den Mengen der Positionen mit vom Bieter
einzutragender Menge, Unterbeschreibungen, Textergänzungen des Bieters, Zuschlagspositionen, Summen
und dem Auftragnehmer aus dem Angebot. Gemeldet werden Elemente des Angebots, die nicht in der
Anfrage stehen (`GAEB-PRC-001`), mehrdeutige OZ (`GAEB-PRC-002`), Position und Zuschlagsposition
mit derselben OZ (`GAEB-PRC-003`) und Zuschlagspositionen ohne Zuschlag (`GAEB-PRC-004`). Das
Beispiel [BidToAward](../../examples/BidToAward/BidToAward.dpr) zeigt den ganzen Ablauf.
