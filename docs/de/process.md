# Der Vergabeprozess

[English](../process.md)

Die Unit `LandrixGaebProcess` arbeitet auf zwei LV desselben Projekts: Anfrage (X83) und Angebot
(X84), Angebot und Auftrag (X86).

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
nie gerundet.

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
