# GAEB-for-Pascal

Pascal-Bibliothek zum Lesen, Schreiben, Prüfen und Konvertieren von GAEB-Dateien (GAEB DA XML
3.2 und 3.3). / Pascal library to read, write, check and convert GAEB files (GAEB DA XML 3.2
and 3.3).

**Status:** Version 1.0.0; die stabilen Units folgen der semantischen Versionierung. / Version
1.0.0; the stable units follow semantic versioning.

- Eine Codebasis für **Delphi 6 bis Delphi 13** und **Free Pascal 3.2.2, 3.2.4 und 3.3.1**
  (Windows, Linux, macOS). / One code base for Delphi 6 to 13 and Free Pascal 3.2.2 to 3.3.1.
- Fachliche Fassade (Bereiche, Positionen, Mengen, Preise, Texte, Angebot und Auftrag) über einem
  vollständigen, aus den Schemas generierten Syntaxmodell; Prüfung der Inhaltsmodelle,
  Geschäfts- und Paarregeln. / Business facade over a complete syntax model generated from the
  schemas; content model check, business rules and pair rules.
- Keine Abhängigkeit von MSXML oder anderen XML-Bibliotheken: XML wird über
  [LandrixXML for Pascal](https://github.com/landrix/LandrixXML-for-Pascal)
  verarbeitet, eingebunden als Git-Submodul (`git clone --recurse-submodules`).

## Schnellstart / Quick start

```pascal
uses
  LandrixGaebTypes, LandrixGaebDiagnostics, LandrixGaebBoQ;

Bill := TLandrixGaebBillOfQuantities.LoadFromFile('request.x83', nil, 0);
try
  for I := 0 to Bill.AllItems.Count - 1 do
    WriteLn(string(Bill.AllItems[I].OZ), '  ', string(Bill.AllItems[I].ShortText));
  Bill.SaveToFile('copy.x83', nil);   // geprüft gegen das Schema / checked against the schema
finally
  Bill.Free;
end;
```

## Dokumentation / Documentation

- Erste Schritte / Getting started: [Deutsch](docs/de/getting-started.md),
  [English](docs/getting-started.md) (Einrichtung, Versionen, Delphi 6, Grenzen / setup,
  versions, Delphi 6, limits)
- Lesen / Reading: [Deutsch](docs/de/reading.md), [English](docs/reading.md)
- Schreiben und Konvertieren / Writing and converting: [Deutsch](docs/de/writing.md),
  [English](docs/writing.md)
- Prüfen / Checking: [Deutsch](docs/de/checking.md), [English](docs/checking.md)
- Vergabeprozess / Bid process: [Deutsch](docs/de/process.md), [English](docs/process.md)
- [Beispiele / Examples](examples/): Konsolenprogramme für Delphi und Free Pascal / console
  programs for Delphi and Free Pascal (`WriteBoQ`, `ReadBoQ`, `CheckGaeb`, `ConvertGaeb`,
  `BidToAward`)

## Öffentliche API / Public API

Jede Unit nennt ihre Stufe in einem Kommentar vor der `unit`-Zeile (`API: stable` oder
`API: internal`); `tools/check-forbidden.py` prüft, dass das Interface einer stabilen Unit keine
interne Unit verwendet. Die stabilen Units fallen ab Version 1.0 unter die semantische
Versionierung. / Every unit states its level in a comment before its `unit` line; the stable units
are covered by semantic versioning from release 1.0 on.

- **Stabil / stable:** `LandrixGaebBoQ` (fachliche Fassade / business facade),
  `LandrixGaebProcess`, `LandrixGaebTypes`, `LandrixGaebDiagnostics`, `LandrixGaebXmlBase`,
  `LandrixGaebXmlModel` (Syntaxmodell / syntax model), `LandrixGaebXmlReader`,
  `LandrixGaebXmlWriter`, `LandrixGaebXmlCheck`, `LandrixGaebRules`, `LandrixGaebDetect`.
- **Intern / internal** (kann sich in jeder Version ändern / may change in any release):
  `LandrixGaebBoQTree`, `LandrixGaebXmlReadBase`, `LandrixGaebXmlWriteBase`,
  `LandrixGaebXmlProfiles`, `LandrixGaebXmlGrammar`, `LandrixGaebXmlCodes`.

Innerhalb von 1.x bleibt der Quelltext kompatibel, nicht das Binärformat: Aufzählungen können
Werte erhalten (unbekannte Werte in einem `else`-Zweig behandeln, keine Ordinalwerte speichern),
Records können Felder erhalten (Schreiboptionen immer mit `LandrixGaebXmlDefaultWriteOptions`
anlegen), Units neue Funktionen und das Syntaxmodell neue Klassen und Mitglieder. / Within 1.x the
source stays compatible, not the binary layout: enumerations may gain values (handle unknown values
in an `else` branch, do not store ordinal values), records may gain fields (always start write
options from `LandrixGaebXmlDefaultWriteOptions`), units may gain functions and the syntax model
new classes and members.

## Lizenz / License

english version below

Die Bibliothek "GAEB-for-Pascal" unterliegt einer Doppellizenz. Sie können sie kostenlos
unter der [GPL v3.0](https://www.gnu.org/licenses/gpl-3.0.en.html) verwenden, oder Sie erwerben
eine Lizenz zur kommerziellen Nutzung unter der [Landrix Software Commercial License](commercial.license.md).

Eine kommerzielle Lizenz gewährt Ihnen das Recht, GAEB-for-Pascal
in Ihren eigenen Anwendungen zu verwenden. Lizenzfrei und ohne Verpflichtung zur
Offenlegung Ihres Quellcodes oder Ihrer Änderungen gegenüber Landrix Software oder einer anderen Partei.
Eine kommerzielle Lizenz gilt auf Dauer und berechtigt Sie kostenlos zu allen zukünftigen Updates.

Jede Firma, die Anwendungen mit der Bibliothek GAEB-for-Pascal entwickelt, benötigt eine Lizenz.
Die Kosten dafür betragen 1.900,00 EUR zzgl. MwSt. pro Firma.

Bitte senden Sie eine E-Mail an info@landrix.de, um eine Rechnung mit den Zahlungsinformationen anzufordern.

Beiträge zum Projekt: siehe [CONTRIBUTING.md](CONTRIBUTING.md). Sicherheitslücken: siehe [SECURITY.md](SECURITY.md).

---

The "GAEB-for-Pascal" library is dual-licensed. You may choose to use it under the restrictions of
the [GPL v3.0](https://www.gnu.org/licenses/gpl-3.0.en.html) at no cost to you, or you may purchase
a licence for commercial use under the [Landrix Software Commercial License](commercial.license.md).

A commercial licence grants you the right to use GAEB-for-Pascal in your own applications,
royalty free, and without any requirement to disclose your source code or your modifications to
Landrix Software or to any other party. A commercial licence lasts into perpetuity, and
entitles you to all future updates, free of charge.

A commercial licence is sold per company developing applications that use GAEB-for-Pascal.
The cost is EUR 1,900.00 plus VAT per company.

Please send an e-mail to info@landrix.de to request an invoice which will contain the bank details.

Contributions: see [CONTRIBUTING.md](CONTRIBUTING.md). Security issues: see [SECURITY.md](SECURITY.md).

GAEB is a standard of the Gemeinsamer Ausschuss Elektronik im Bauwesen. This project is not
affiliated with or endorsed by GAEB.
