# Erste Schritte

[English](../getting-started.md)

GAEB-for-Pascal liest, schreibt, prüft und konvertiert GAEB-DA-XML-Dateien: Leistungsverzeichnisse,
Angebote, Aufträge und die übrigen Austauschphasen der Bauwirtschaft. Eine Codebasis übersetzt mit
Delphi 6 bis Delphi 13 und Free Pascal 3.2.2, 3.2.4 und 3.3.1 (Windows, Linux, macOS).

## Einrichtung

1. Quellen mit dem Submodul LandrixXML holen:

   ```
   git clone --recurse-submodules https://github.com/LandrixSoftware/GAEB-for-Pascal.git
   ```

   In einem vorhandenen Klon: `git submodule update --init`.

2. Zwei Ordner in den Suchpfad des Projekts aufnehmen (Units und Include-Dateien):

   - `source`
   - `external/landrix-xml/source`

   Delphi: *Projekt > Optionen > Delphi-Compiler > Suchpfad*. Lazarus: *Projekt >
   Projekteinstellungen > Compilereinstellungen > Pfade > Andere Unit-Dateien* und
   *Include-Dateien*.

3. Free Pascal: im Delphi-Modus übersetzen (`{$MODE DELPHI}` im Programm oder `-Mdelphi`). Unter
   Unix `cwstring` als erste Unit des Programms einbinden, wenn es Texte ausgibt oder Dateinamen mit
   Nicht-ASCII-Zeichen verarbeitet (Umwandlung zwischen UTF-8 und dem nativen string); die
   Bibliothek selbst braucht sie nicht.

## Zwei Ebenen

| Ebene | Units | Wofür |
|---|---|---|
| Fachliche Fassade | `LandrixGaebBoQ`, `LandrixGaebProcess` | Das LV als Bereiche, Positionen, Mengen, Preise, Positionsarten, Parteien und Texte; Zuordnung, Summen, Auftrag zusammensetzen. |
| Syntaxmodell | `LandrixGaebXmlModel`, `LandrixGaebXmlReader`, `LandrixGaebXmlWriter` | Das Dokument Element für Element, aus den Schemas generiert: alles, was GAEB DA XML enthält. |

Die Fassade hält keine Kopie: Jeder Wert wird aus dem Syntaxmodell gelesen und in es geschrieben.
Was der Leser nicht übernehmen konnte (Elemente, die das Ziel nicht kennt, Werte, die keine gültige
Dezimalzahl sind), meldet er in den Meldungen; mit einer `TLandrixGaebDiagnostics` lesen, um es zu
sehen. `TLandrixGaebBillOfQuantities.Document` und
`SyntaxNode` jeder Sicht führen zum Syntaxmodell, wenn die Fassade etwas nicht abdeckt.

Die stabilen Units und die Regeln für spätere Versionen stehen im README, Abschnitt
*Öffentliche API*.

## Unterstützte Versionen

Lesen, Schreiben und Prüfen decken die Austauschphasen des Leistungsverzeichnisses ab, DA 80 bis
87 (80 bis 82 Leistungsverzeichnis, 83 Angebotsaufforderung, 84 Angebot, 85 Nebenangebot, 86 Auftrag,
87 Auftragsbestätigung):

| Version | Ausgabe | Lesen und Prüfen | Schreiben |
|---|---|---|---|
| GAEB DA XML 3.2 | 2013-10 | DA 80 bis 87 | DA 80 bis 87 |
| GAEB DA XML 3.3 | 2021-05 | DA 80 bis 87 | DA 80 bis 87 |
| GAEB DA XML 3.3 | 2019-11 | DA 80 bis 87 | nein (2021-05 schreiben) |

Andere Phasen (etwa Zeitverträge, Mengenermittlung X31, Rechnungen X89), GAEB DA XML 3.0, 3.1 und
die Beta 3.4, GAEB DA 2000 und GAEB 90 werden erkannt (`LandrixGaebDetectFile`), nicht gelesen.

Ein Ziel nennt Version, Ausgabe und Austauschphase:

```pascal
LandrixGaebTarget(gv33, ge2021_05, gp83)   // Anfrage X83, GAEB DA XML 3.3
LandrixGaebTarget(gv32, ge2013_10, gp84)   // Angebot X84, GAEB DA XML 3.2
```

## Ein erstes Programm

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

Die Beispiele unter [examples/](../../examples/) sind vollständige Konsolenprogramme: ein neues LV
schreiben (`WriteBoQ`), lesen (`ReadBoQ`), prüfen (`CheckGaeb`), konvertieren (`ConvertGaeb`) und
aus Anfrage und Angebot den Auftrag bilden (`BidToAward`). `tools/build.ps1` übersetzt und startet
sie nach den Tests mit jeder Windows- und Linux-Toolchain (nicht in den Varianten mit
Bereichsprüfung und nicht unter macOS).

## Zeichenketten und Zahlen

- Texte sind `TLandrixGaebString`: UTF-16 unter jedem Compiler (`WideString` unter Delphi 6 bis
  2007, `string` ab Delphi 2009, `UnicodeString` unter Free Pascal), es geht kein Zeichen verloren.
  `LandrixXmlUtf8ToString(LandrixXmlWideToUtf8(S))` liefert den nativen `string`.
- Mengen und Preise sind nie `Double`. `TLandrixGaebDecimal` hält den Wert genau wie geschrieben
  (Koeffizient und Skala; `12.500` behält drei Stellen); Funktionen wie `Item.Qty` liefern eine
  Kopie, `SetQty` und `ClearQty` ändern das Dokument. Beträge werden mit `LandrixXmlDecimal`
  gerechnet und kaufmännisch gerundet (bei genau halb weg von null).
- Nichts hängt von den Ländereinstellungen ab.

## Grenzen und nicht vertrauenswürdige Eingaben

GAEB-Dateien von außen sind nicht vertrauenswürdig. Beim Lesen werden Eingaben über
`LandrixGaebDefaultMaxSize` (256 MB; der Parameter `AMaxSize` setzt eine andere Grenze),
jede Dokumenttyp-Deklaration, externe Entitäten und nicht wohlgeformtes XML mit Ausnahme und
Position abgelehnt, nie geraten. Siehe [SECURITY.md](../../SECURITY.md).

## Hinweise zu Delphi 6

- `TLandrixGaebString` ist `WideString`: die Zuweisung an `string` wandelt in die Codepage des
  Systems; Zeichen außerhalb davon werden zu `?`.
- `TLandrixGaebDecimal` ist ein `object` alter Art, Records haben keine Methoden: Die Bibliothek
  nutzt nur, was Delphi 6 übersetzen kann, und der Build prüft jede Änderung mit einem echten
  Delphi 6.
