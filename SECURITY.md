# Sicherheit / Security

[Deutsch](#deutsch) | [English](#english)

## Deutsch

Stand: 21. Oktober 2026

### Eine Schwachstelle melden

Bitte melden Sie mögliche Sicherheitslücken in GAEB-for-Pascal an
**[info@landrix.de](mailto:info@landrix.de)**, mit dem Betreff
`[Security] GAEB-for-Pascal: kurze Beschreibung`.
Bitte eröffnen Sie für noch nicht behobene Schwachstellen zunächst kein öffentliches Issue
und veröffentlichen Sie keine ausnutzbaren Beispieldateien.

Hilfreich sind:

- Bibliotheksversion und möglichst Git-Commit (auch des Submoduls `external/landrix-xml`) sowie
  Angaben zu eigenen Änderungen.
- Compiler, Betriebssystem und Architektur.
- Betroffener Aufruf und aktivierte Optionen.
- Schritte zur Reproduktion, erwartetes und beobachtetes Verhalten sowie mögliche Auswirkungen.
- Eine minimale Beispieldatei mit künstlichen Daten; keine echten Leistungsverzeichnisse,
  Angebotspreise, Zugangsdaten oder personenbezogenen Daten.

Die E-Mail-Adresse ist ein privater Kontaktweg, keine Zusage einer Ende-zu-Ende-verschlüsselten
Übertragung oder einer rund um die Uhr besetzten Meldestelle.

### Unterstützte Versionen und Bearbeitung

Das Projekt befindet sich in der Entwicklung; es gibt noch keine veröffentlichte Version.
Es ist keine verbindliche Tabelle mit Sicherheits-Supportzeiträumen je Release veröffentlicht.
Es werden hier keine festen Reaktionszeiten, Behebungsfristen oder Rückportierungen zugesagt.
Vertragliche Rechte und gesetzliche Pflichten bleiben unberührt; dieses Dokument ändert nicht
die Lizenzbedingungen.

### Hinweise zur Integration

GAEB-Dateien sind als nicht vertrauenswürdige Eingaben zu behandeln.
Hersteller der einbindenden Anwendung sollten insbesondere Ressourcenlimits und die
Parserkonfiguration (z. B. externe Entitäten, DTDs) prüfen. Validierung ersetzt diese Prüfungen
nicht.

## English

As of 21 October 2026

### Reporting a vulnerability

Please report potential security vulnerabilities in GAEB-for-Pascal to
**[info@landrix.de](mailto:info@landrix.de)**, using the subject
`[Security] GAEB-for-Pascal: short description`.
Please do not initially open a public issue for an unresolved vulnerability or publish
files that demonstrate how to exploit it.

Useful information includes:

- Library version and preferably Git commit (including the `external/landrix-xml` submodule),
  together with details of local modifications.
- Compiler, operating system and architecture.
- Affected API call and enabled options.
- Reproduction steps, expected and observed behaviour, and potential impact.
- A minimal sample using synthetic data; no real bills of quantities, bid prices,
  credentials or personal data.

The email address is a private contact channel, not a promise of end-to-end encrypted
transmission or a reporting service staffed around the clock.

### Supported versions and handling

The project is under development; there is no published release yet.
No binding table of security support periods per release is published.
This document does not promise fixed response times, remediation deadlines or backports.
Contractual rights and statutory obligations remain unaffected; this document does not
change licence terms.

### Integration guidance

Treat GAEB files as untrusted input. Manufacturers integrating the
library should review resource limits and parser configuration (e.g. external entities, DTDs).
Validation does not replace these checks.
