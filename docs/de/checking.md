# Prüfen

[English](../checking.md)

Eine GAEB-Datei wird in Stufen geprüft. Jede Stufe fügt ihre Befunde einer
`TLandrixGaebDiagnostics` hinzu; die Erkennung liefert einen Record mit `Accepted`, die übrigen
Stufen liefern `True`, wenn sie keinen Fehler gefunden haben.

| Stufe | Funktion | Unit | Was |
|---|---|---|---|
| 1 | `LandrixGaebDetectFile` | `LandrixGaebDetect` | Format, Version, Ausgabe, Phase aus dem Anfang der Datei; lehnt Eingaben ab, die nicht verarbeitet werden dürfen (Größengrenze, Dokumenttyp-Deklaration, im gelesenen Teil nicht wohlgeformt, unbekanntes Format); die ganze Datei prüfen das Lesen oder Stufe 2 auf Wohlgeformtheit |
| 2 | `LandrixGaebXmlCheckFile` | `LandrixGaebXmlCheck` | Inhaltsmodelle des Schemas des angegebenen Ziels: Reihenfolge und Anzahl der Elemente, einfache Typen mit allen Facetten, ID und IDREF |
| 3 | `LandrixGaebCheckRules` | `LandrixGaebRules` | Geschäftsregeln der Phase auf dem Syntaxmodell |
| 4 | `LandrixGaebCheckPair` | `LandrixGaebRules` | Paarregeln zwischen zwei Dokumenten: X83 -> X84, X84 -> X86, X86 -> X87 |

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

Das Beispiel [CheckGaeb](../../examples/CheckGaeb/CheckGaeb.dpr) führt alle Stufen aus und mit
einer zweiten Datei die Paarregeln; mit `-xsd=<Ordner>` auch die Prüfung gegen die
Originalschemas.

Stufe 2 ist kein allgemeiner XML-Schema-Validator: Sie kennt genau die Schemas der unterstützten
Ziele. Maßstab bleibt die Prüfung gegen die Originalschemas.

## Prüfung gegen die Originalschemas

`LandrixGaebXmlXsd` (ab 1.1.0) prüft gegen die originalen GAEB-XSD-Dateien mit dem
XML-Schema-Validator von LandrixXml. Die Schemas gehören nicht zur Bibliothek: Sie laden sie von
gaeb.de in einen eigenen Ordner, zum Beispiel mit

```
pwsh tools/fetch-gaeb-xsd.ps1 -Folder C:\GAEB\Schemas
```

Das Skript holt die Pakete für GAEB DA XML 3.2 (2013-10) und 3.3 (2021-05) und prüft jede Datei
gegen die SHA-256, die die Bibliothek kennt. Die Ausgabe 2019-11 von 3.3 bietet der GAEB nicht
mehr an; wer sie braucht, legt die Schemas selbst in den Ordner.

```pascal
Schemas := TLandrixGaebXmlXsdSchemas.Create('C:\GAEB\Schemas');
try
  Ok := LandrixGaebXmlXsdValidateFile(Schemas, 'bid.x84', Diags, 0, Det);
  { das LV so, wie SaveToFile es schreiben würde, vor dem Speichern }
  Ok := LandrixGaebXmlXsdValidateBill(Schemas, Bill, Diags);
finally
  Schemas.Free;
end;
```

- Ein Hauptschema (`GAEB_DA_XML_84_3.3_2021-05.xsd`) wird über seinen Namen irgendwo unterhalb
  des Ordners gesucht; seine Lib-Datei muss daneben liegen. Ein doppelt gefundenes Hauptschema
  ist ein Fehler.
- Ein fehlendes oder nicht ladbares Schema löst `ELandrixGaebError` aus; `False` heißt immer,
  dass das Dokument ungültig ist. `HasTarget` fragt, ohne zu laden.
- Befunde sind `GAEB-XSD-001` (Fehler); der Code des Validators (Xerces, z. B.
  `cvc-complex-type.2.4.a`) steht in `XsdCode` der Meldung und in Klammern im Text. Meldungen
  zitieren nie Werte des Dokuments. `GAEB-XSD-002` (Warnung) sagt, dass ein Teil nicht geprüft
  wurde (nach 1000 Fehlern hört der Validator auf).
- Eine Schemadatei, die von der offiziellen Datei abweicht, wird verwendet, mit der Warnung
  `GAEB-XSD-003` bei jeder Prüfung; `Verify` vergleicht alle Dateien des Ordners.
- Schemadokumente werden nur aus dem Ordner gelesen (die Suche folgt keinen Links); der Ordner
  ist vertrauenswürdige Eingabe. Ein
  `TLandrixGaebXmlXsdSchemas` behält die geladenen Schemas: einmal anlegen, eines je Thread.

Die XSD-Prüfung ergänzt Stufe 2, sie ersetzt sie nicht: Stufe 2 ist schneller und Teil jedes
Schreibens.

## Meldungen

Jeder Befund hat eine stabile Regelkennung (`RuleId`), eine Schwere (`gsInformation`, `gsWarning`,
`gsError`, `gsFatal`), den Pfad des Elements, Zeile und Spalte, soweit bekannt, und einen
englischen Text. Die Texte enthalten keine Werte des LV (Texte, Mengen, Preise); einige nennen,
was die Eingabe angibt, etwa einen fremden Namensraum, daher Protokolle wie die Eingabe behandeln.

| Präfix | Herkunft |
|---|---|
| `GAEB-DET-...` | Erkennung |
| `GAEB-XML-...` | Lesen |
| `GAEB-CHK-...` | Prüfung der Inhaltsmodelle |
| `GAEB-WRT-...` | Schreiben (Verluste, ersetzte Werte) |
| `GAEB-BR-...` | Geschäfts- und Paarregeln |
| `GAEB-PRC-...` | Prozessfunktionen |

`Diags.ToText` liefert eine Zeile je Befund zur Anzeige; `ToWideText` behält jedes Zeichen der
Pfade auch unter Compilern, deren `string` nicht Unicode ist.

## Der Regelkatalog

`LandrixGaebRuleCount`, `LandrixGaebRuleAt(I)` und `LandrixGaebRuleIndex(ID)` führen die Regeln mit
Kennung, Titel, Schwere, den Phasen, für die sie gelten, ob sie zwei Dokumente brauchen, und dem
Abschnitt der GAEB-Dokumentation, auf dem sie beruhen. `LandrixGaebRuleSetVersion` nennt die
Version des Regelwerks; sie ändert sich unabhängig von der Bibliotheksversion.

Fehler sind Verstöße, die ein Dokument mehrdeutig oder seine Beträge falsch machen: OZ eindeutig
und passend zur Gliederung, Mengen, Pauschale und vom Bieter einzutragende Menge, EP-Anteile,
Gesamtbeträge der Positionen und Summen der Bereiche und des LV (exakt gerechnet, kaufmännisch
gerundet), Bezugsbeschreibungen, Ausführungsbeschreibungen, Zuschlagspositionen und zwischen
Anfrage und Angebot die Positionen, Bereiche, Stellen der Einheitspreise, Summen und
Textergänzungen. Formverstöße, die echte Exportprogramme erzeugen, sind Warnungen. Zwischen
Angebot, Auftrag und Auftragsbestätigung dürfen sich Preise in der Verhandlung ändern, daher sind
diese Paarregeln Warnungen.
