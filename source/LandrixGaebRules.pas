{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Business rules of GAEB DA XML (stage 3) and pair rules over two documents
  (stage 4), checked on the syntax model (LandrixGaebXmlModel). The
  catalogue LandrixGaebRuleCatalog lists every rule with a stable identifier, the
  phases it applies to and the section of the GAEB documentation it is
  based on (a reference, never a quotation). Rules that the schema of the
  target already enforces are left to the content model check (stage 2,
  LandrixGaebXmlCheck); this unit expects documents that passed it, but
  never fails on documents that did not.

  The ordinal number (OZ) of an item is formed from the RNoPart of every
  enclosing category, the RNoPart of the item and its RNoIndex. All amounts
  are computed exactly (LandrixXmlDecimal) and rounded commercially (half
  away from zero). Messages are English and never contain values of the
  document; the path names the element.

  DE: Geschaeftsregeln von GAEB DA XML (Stufe 3) und Paarregeln ueber zwei
  Dokumente (Stufe 4), geprueft auf dem Syntaxmodell
  (LandrixGaebXmlModel). Der Katalog LandrixGaebRuleCatalog fuehrt jede Regel mit
  stabiler Kennung, den Phasen, fuer die sie gilt, und dem Abschnitt der
  GAEB-Dokumentation, auf dem sie beruht (ein Verweis, nie ein Zitat).
  Regeln, die das Schema des Ziels schon erzwingt, bleiben der Pruefung der
  Inhaltsmodelle ueberlassen (Stufe 2, LandrixGaebXmlCheck); diese Unit
  erwartet Dokumente, die sie bestanden haben, scheitert aber nie an
  Dokumenten, die das nicht haben.

  Die Ordnungszahl (OZ) einer Position wird aus dem RNoPart jeder
  umgebenden Kategorie, dem RNoPart der Position und ihrem RNoIndex
  gebildet. Alle Betraege werden exakt gerechnet (LandrixXmlDecimal) und
  kaufmaennisch gerundet (bei genau halb weg von null). Die Texte sind
  englisch und enthalten nie Werte des Dokuments; der Pfad nennt das
  Element. }

{ API: internal. May change in any release before 1.0.
  DE: API: intern. Kann sich vor Version 1.0 in jeder Version aendern. }

unit LandrixGaebRules;

{$I LandrixGaeb.inc}

interface

uses
  SysUtils,
  Classes,
  Contnrs,
  LandrixXmlBase,
  LandrixXmlDecimal,
  LandrixGaebTypes,
  LandrixGaebDiagnostics,
  LandrixGaebXmlBase,
  LandrixGaebXmlModel;

const
  { Version of the rule set, independent of the library version.
    DE: Version des Regelwerks, unabhaengig von der Bibliotheksversion. }
  LandrixGaebRuleSetVersion = '2026.1';
  { Number of rules in the catalogue. DE: Anzahl der Regeln im Katalog. }
  LandrixGaebRuleCount = 45;

type
  { One rule of the catalogue. Source names the section of the GAEB
    documentation (reference only). A record without methods (Delphi 6).
    DE: Eine Regel des Katalogs. Source nennt den Abschnitt der
    GAEB-Dokumentation (nur Verweis). Record ohne Methoden (Delphi 6). }
  TLandrixGaebRule = record
    { Stable identifier. DE: Stabile Kennung. }
    ID: string;
    { Own wording, English. DE: Eigene Formulierung, englisch. }
    Title: string;
    { Severity of a finding. DE: Schwere eines Befunds. }
    Severity: TLandrixGaebSeverity;
    { Phases of the document (pair rules: of the second document).
      DE: Phasen des Dokuments (Paarregeln: des zweiten Dokuments). }
    Phases: TLandrixGaebPhases;
    { True if the rule needs two documents. DE: True, wenn die Regel zwei
      Dokumente braucht. }
    Pair: Boolean;
    { Section of the GAEB documentation the rule is based on.
      DE: Abschnitt der GAEB-Dokumentation, auf dem die Regel beruht. }
    Source: string;
  end;

const
  { The catalogue. Errors are violations that make a document ambiguous or
    its amounts wrong; violations of form that real exporters produce are
    warnings.
    DE: Der Katalog. Fehler sind Verstoesse, die ein Dokument mehrdeutig
    oder seine Betraege falsch machen; Formverstoesse, die echte
    Exportprogramme erzeugen, sind Warnungen. }
  LandrixGaebRuleCatalog: array[0..LandrixGaebRuleCount - 1] of TLandrixGaebRule = (
    (ID: 'GAEB-BR-OZ-001'; Title: 'OZ unique within the bill of quantities';
      Severity: gsError; Phases: [gp80, gp81, gp82, gp83, gp84, gp85, gp86, gp87]; Pair: False;
      Source: 'Fachdokumentation 3.3 (2023-01), 4.2.1'),
    (ID: 'GAEB-BR-OZ-002'; Title: 'OZ at most 14 characters including the index';
      Severity: gsError; Phases: [gp80, gp81, gp82, gp83, gp84, gp85, gp86, gp87]; Pair: False;
      Source: 'Fachdokumentation 3.3 (2023-01), 4.2.1, 4.3.3'),
    (ID: 'GAEB-BR-OZ-003'; Title: 'OZ fits the breakdown of BoQBkdn (levels, lengths, index)';
      Severity: gsError; Phases: [gp80, gp81, gp82, gp83, gp84, gp85, gp86, gp87]; Pair: False;
      Source: 'Fachdokumentation 3.3 (2023-01), 4.3.4'),
    (ID: 'GAEB-BR-OZ-004'; Title: 'OZ ascending in document order';
      Severity: gsWarning; Phases: [gp80, gp81, gp82, gp83, gp84, gp85, gp86, gp87]; Pair: False;
      Source: 'Fachdokumentation 3.3 (2023-01), 4.2.1'),
    (ID: 'GAEB-BR-OZ-005'; Title: 'Part of an OZ shorter than its level although not numeric';
      Severity: gsInformation; Phases: [gp80, gp81, gp82, gp83, gp84, gp85, gp86, gp87]; Pair: False;
      Source: 'corpus; Fachdokumentation 3.3 (2023-01), 4.3'),
    (ID: 'GAEB-BR-OZ-006'; Title: 'Part of an OZ made of zeros or underscores only';
      Severity: gsWarning; Phases: [gp80, gp81, gp82, gp83, gp84, gp85, gp86, gp87]; Pair: False;
      Source: 'Fachdokumentation 3.3 (2023-01), 4.2.1'),
    (ID: 'GAEB-BR-BKDN-001'; Title: 'Lengths of all BoQBkdn parts at most 14 together';
      Severity: gsError; Phases: [gp80, gp81, gp82, gp83, gp84, gp85, gp86, gp87]; Pair: False;
      Source: 'Fachdokumentation 3.3 (2023-01), 11.2.3 BoQInfo 2'),
    (ID: 'GAEB-BR-BKDN-002'; Title: 'BoQBkdn order: Lot once and first, at most five levels, Item once, Index once after Item';
      Severity: gsError; Phases: [gp80, gp81, gp82, gp83, gp84, gp85, gp86, gp87]; Pair: False;
      Source: 'Fachdokumentation 3.3 (2023-01), 11.2.3 BoQInfo 3-8'),
    (ID: 'GAEB-BR-BKDN-003'; Title: 'Index of the breakdown has length 1';
      Severity: gsError; Phases: [gp80, gp81, gp82, gp83, gp84, gp85, gp86, gp87]; Pair: False;
      Source: 'Fachdokumentation 3.3 (2023-01), 11.2.3 BoQBkdn 2'),
    (ID: 'GAEB-BR-BKDN-004'; Title: 'Label of a breakdown part only for BoQLevel';
      Severity: gsWarning; Phases: [gp80, gp81, gp82, gp83, gp84, gp85, gp86, gp87]; Pair: False;
      Source: 'Fachdokumentation 3.3 (2023-01), 11.2.3 BoQBkdn 1'),
    (ID: 'GAEB-BR-UP-002'; Title: 'Labels of unit price components match NoUPComps';
      Severity: gsError; Phases: [gp80, gp81, gp82, gp83, gp85, gp86, gp87]; Pair: False;
      Source: 'Fachdokumentation 3.3 (2023-01), 11.2.3 BoQInfo 9-10'),
    (ID: 'GAEB-BR-QTY-001'; Title: 'QtySplit not together with QtyTBD';
      Severity: gsError; Phases: [gp80, gp81, gp82, gp83, gp86, gp87]; Pair: False;
      Source: 'Fachdokumentation 3.3 (2023-01), 4.6.11, 11.2.3 Item 5'),
    (ID: 'GAEB-BR-QTY-002'; Title: 'Quantities of QtySplit add up to the quantity of the item';
      Severity: gsError; Phases: [gp80, gp81, gp82, gp83, gp85, gp86, gp87]; Pair: False;
      Source: 'Fachdokumentation 3.3 (2023-01), 11.2.3 Item 6'),
    (ID: 'GAEB-BR-QTY-003'; Title: 'Item with QtyTBD has no quantity';
      Severity: gsError; Phases: [gp83]; Pair: False;
      Source: 'Fachdokumentation 3.3 (2023-01), 4.6.11, 11.2.3 Item 3'),
    (ID: 'GAEB-BR-QTY-004'; Title: 'Quantity missing only with QtyTBD or LumpSumItem';
      Severity: gsError; Phases: [gp80, gp81, gp82, gp83, gp85, gp86, gp87]; Pair: False;
      Source: 'Fachdokumentation 3.3 (2023-01), 11.2.3 Item 2'),
    (ID: 'GAEB-BR-QTY-005'; Title: 'Lump sum item not together with QtyTBD';
      Severity: gsError; Phases: [gp80, gp81, gp82, gp83, gp86, gp87]; Pair: False;
      Source: 'Fachdokumentation 3.3 (2023-01), 4.5.5'),
    (ID: 'GAEB-BR-QTY-006'; Title: 'Lump sum item without quantity or with quantity 1';
      Severity: gsError; Phases: [gp80, gp81, gp82, gp83, gp85, gp86, gp87]; Pair: False;
      Source: 'Fachdokumentation 3.3 (2023-01), 4.5.1'),
    (ID: 'GAEB-BR-ITEM-001'; Title: 'Item has a description';
      Severity: gsError; Phases: [gp80, gp81, gp82, gp83, gp85, gp86, gp87]; Pair: False;
      Source: 'Fachdokumentation 3.3 (2023-01), 11.2.3 Item 7'),
    (ID: 'GAEB-BR-ITEM-002'; Title: 'Item with SumDescr has SubDescr';
      Severity: gsError; Phases: [gp80, gp81, gp82, gp83, gp85, gp86, gp87]; Pair: False;
      Source: 'Fachdokumentation 3.3 (2023-01), 4.6.12, 11.2.3 Item 9'),
    (ID: 'GAEB-BR-TXT-001'; Title: 'Repetition description refers to an item that is no repetition';
      Severity: gsError; Phases: [gp80, gp81, gp82, gp83, gp85, gp86, gp87]; Pair: False;
      Source: 'Fachdokumentation 3.3 (2023-01), 4.4.4'),
    (ID: 'GAEB-BR-TXT-002'; Title: 'Repetition description keeps the unit of its reference';
      Severity: gsWarning; Phases: [gp80, gp81, gp82, gp83, gp85, gp86, gp87]; Pair: False;
      Source: 'Fachdokumentation 3.3 (2023-01), 4.4.4'),
    (ID: 'GAEB-BR-TXT-003'; Title: 'Reference description precedes its repetitions';
      Severity: gsError; Phases: [gp80, gp81, gp82, gp83, gp85, gp86, gp87]; Pair: False;
      Source: 'Fachdokumentation 3.3 (2023-01), 4.4.4'),
    (ID: 'GAEB-BR-TXT-004'; Title: 'Long text with text complements has ComplTSA or ComplTSB';
      Severity: gsError; Phases: [gp80, gp81, gp82, gp83, gp85, gp86, gp87]; Pair: False;
      Source: 'Fachdokumentation 3.3 (2023-01), 11.2.3 Description 1'),
    (ID: 'GAEB-BR-PERF-001'; Title: 'Number of an execution description unique';
      Severity: gsError; Phases: [gp80, gp81, gp82, gp83, gp84, gp85, gp86, gp87]; Pair: False;
      Source: 'Fachdokumentation 3.3 (2023-01), 4.4.3, 11.2.3 PerfDescr 1'),
    (ID: 'GAEB-BR-PERF-002'; Title: 'Execution description precedes the items that refer to it';
      Severity: gsError; Phases: [gp80, gp81, gp82, gp83, gp85, gp86, gp87]; Pair: False;
      Source: 'Fachdokumentation 3.3 (2023-01), 4.4.3, 11.2.3 PerfDescr 2'),
    (ID: 'GAEB-BR-MKUP-001'; Title: 'MarkupSubQty exactly with MarkupType ListInSubQty';
      Severity: gsError; Phases: [gp80, gp81, gp82, gp83, gp85, gp86, gp87]; Pair: False;
      Source: 'Fachdokumentation 3.3 (2023-01), 11.2.3 MarkupItem 4'),
    (ID: 'GAEB-BR-UP-001'; Title: 'Unit price components add up to the unit price';
      Severity: gsError; Phases: [gp80, gp81, gp82, gp84, gp85, gp86, gp87]; Pair: False;
      Source: 'Fachdokumentation 3.3 (2023-01), 4.6.5'),
    (ID: 'GAEB-BR-X84-001'; Title: 'Item not offered has no unit price';
      Severity: gsError; Phases: [gp84]; Pair: False;
      Source: 'Fachdokumentation 3.3 (2023-01), 4.6.4'),
    (ID: 'GAEB-BR-SUM-001'; Title: 'Total of an item is quantity times unit price, rounded';
      Severity: gsError; Phases: [gp80, gp81, gp82, gp84, gp85, gp86, gp87]; Pair: False;
      Source: 'Fachdokumentation 3.3 (2023-01), 4.6.17'),
    (ID: 'GAEB-BR-SUM-002'; Title: 'Total after discount follows from total and discount';
      Severity: gsError; Phases: [gp80, gp81, gp82, gp84, gp85, gp86, gp87]; Pair: False;
      Source: 'Fachdokumentation 3.3 (2023-01), 4.6.7, 4.6.17, 11.2.3 Totals 1'),
    (ID: 'GAEB-BR-SUM-003'; Title: 'Total of a category or of the bill is the sum of its counting items and subcategories';
      Severity: gsError; Phases: [gp80, gp81, gp82, gp85, gp86, gp87]; Pair: False;
      Source: 'Fachdokumentation 3.3 (2023-01), 4.2.3, 4.5.2, 4.5.3, 4.6.17'),
    (ID: 'GAEB-BR-PAIR-83-84-001'; Title: 'Items of the bid are the items of the request (by OZ)';
      Severity: gsError; Phases: [gp84]; Pair: True;
      Source: 'Fachdokumentation 3.3 (2023-01), 4.6.19'),
    (ID: 'GAEB-BR-PAIR-83-84-002'; Title: 'Categories of the bid are the categories of the request (by OZ)';
      Severity: gsError; Phases: [gp84]; Pair: True;
      Source: 'Fachdokumentation 3.3 (2023-01), 4.6.19'),
    (ID: 'GAEB-BR-PAIR-83-84-003'; Title: 'Unit prices of the bid have at most UPFracDig significant fraction digits';
      Severity: gsError; Phases: [gp84]; Pair: True;
      Source: 'schema tgUPFracDig (PrjInfo of X83)'),
    (ID: 'GAEB-BR-PAIR-83-84-004'; Title: 'Total of an offered item is the quantity of the request times the unit price, rounded';
      Severity: gsError; Phases: [gp84]; Pair: True;
      Source: 'Fachdokumentation 3.3 (2023-01), 4.6.17'),
    (ID: 'GAEB-BR-PAIR-83-84-005'; Title: 'Unit price components only up to NoUPComps of the request';
      Severity: gsError; Phases: [gp84]; Pair: True;
      Source: 'Fachdokumentation 3.3 (2023-01), 4.6.5, 11.2.3 BoQInfo 10'),
    (ID: 'GAEB-BR-PAIR-83-84-006'; Title: 'Quantity in the bid only for items with QtyTBD';
      Severity: gsError; Phases: [gp84]; Pair: True;
      Source: 'Fachdokumentation 3.3 (2023-01), 4.5.5; Regeln fuer X84 (3.1 2009-12)'),
    (ID: 'GAEB-BR-PAIR-83-84-007'; Title: 'Text complements of the bid keep the numbers of the request';
      Severity: gsError; Phases: [gp84]; Pair: True;
      Source: 'Fachdokumentation 3.3 (2023-01), 4.6.16'),
    (ID: 'GAEB-BR-PAIR-83-84-008'; Title: 'Total of a category is the sum of its counting items and subcategories';
      Severity: gsError; Phases: [gp84]; Pair: True;
      Source: 'Fachdokumentation 3.3 (2023-01), 4.2.3, 4.5.2, 4.5.3, 4.6.17'),
    { X84 -> X86: the documentation sets no rules; the award rests on the
      bid, prices may change in negotiation, so these are warnings
      (owner decision 11.11.2026).
      DE: X84 -> X86: die Dokumentation legt keine Regeln fest; der Auftrag
      beruht auf dem Angebot, Preise koennen sich in der Verhandlung
      aendern, daher Warnungen (Entscheidung des Eigentuemers 11.11.2026). }
    (ID: 'GAEB-BR-PAIR-84-86-001'; Title: 'Items and categories of the award are those of the bid (by OZ)';
      Severity: gsWarning; Phases: [gp86]; Pair: True;
      Source: 'Fachdokumentation 3.3 (2023-01), 2.3 (award on the bid); own rule'),
    (ID: 'GAEB-BR-PAIR-84-86-002'; Title: 'Unit prices of the award are those of the bid';
      Severity: gsWarning; Phases: [gp86]; Pair: True;
      Source: 'Fachdokumentation 3.3 (2023-01), 2.3 (award on the bid); own rule'),
    (ID: 'GAEB-BR-PAIR-84-86-003'; Title: 'Quantities of the award are those of the bid';
      Severity: gsWarning; Phases: [gp86]; Pair: True;
      Source: 'Fachdokumentation 3.3 (2023-01), 2.3 (award on the bid); own rule'),
    { X86 -> X87: the order confirmation may confirm the award in modified
      form (documentation 2.3, 4.6.3), so these are warnings (owner decision
      11.11.2026).
      DE: X86 -> X87: die Auftragsbestaetigung darf den Auftrag auch in
      geaenderter Form bestaetigen (Dokumentation 2.3, 4.6.3), daher
      Warnungen (Entscheidung des Eigentuemers 11.11.2026). }
    (ID: 'GAEB-BR-PAIR-86-87-001'; Title: 'Items and categories of the confirmation are those of the award (by OZ)';
      Severity: gsWarning; Phases: [gp87]; Pair: True;
      Source: 'Fachdokumentation 3.3 (2023-01), 2.3, 4.6.3 (confirmation, also modified); own rule'),
    (ID: 'GAEB-BR-PAIR-86-87-002'; Title: 'Unit prices of the confirmation are those of the award';
      Severity: gsWarning; Phases: [gp87]; Pair: True;
      Source: 'Fachdokumentation 3.3 (2023-01), 2.3, 4.6.3 (confirmation, also modified); own rule'),
    (ID: 'GAEB-BR-PAIR-86-87-003'; Title: 'Quantities of the confirmation are those of the award';
      Severity: gsWarning; Phases: [gp87]; Pair: True;
      Source: 'Fachdokumentation 3.3 (2023-01), 2.3, 4.6.3 (confirmation, also modified); own rule')
  );

{ Index of a rule in LandrixGaebRuleCatalog, -1 if unknown.
  DE: Index einer Regel in LandrixGaebRuleCatalog, -1, wenn unbekannt. }
function LandrixGaebRuleIndex(const AID: string): Integer;

{ Checks the business rules of ATarget's phase on ADocument. True if no
  diagnostic of severity gsError or higher was added. Phases without rules
  give True. ADiagnostics may be nil.
  DE: Prueft die Geschaeftsregeln der Phase von ATarget an ADocument. True,
  wenn keine Meldung der Schwere gsError oder hoeher hinzukam. Phasen ohne
  Regeln liefern True. ADiagnostics darf nil sein. }
function LandrixGaebCheckRules(ADocument: TLandrixGaebXmlGAEB; const ATarget: TLandrixGaebTarget;
  ADiagnostics: TLandrixGaebDiagnostics): Boolean;

{ Checks the pair rules of two documents (X83 -> X84, X84 -> X86, X86 -> X87). Items and
  categories are matched by OZ. Paths of the diagnostics belong to the
  second document, except for elements that are missing there (then the
  path of the first document; the message says so). Raises
  ELandrixGaebError for a pair of phases without pair rules.
  DE: Prueft die Paarregeln zweier Dokumente (X83 -> X84, X84 -> X86,
  X86 -> X87).
  Positionen und Kategorien werden ueber die OZ zugeordnet. Die Pfade der
  Meldungen gehoeren zum zweiten Dokument, ausser bei Elementen, die dort
  fehlen (dann der Pfad im ersten Dokument; der Text sagt es). Loest fuer
  ein Phasenpaar ohne Paarregeln ELandrixGaebError aus. }
function LandrixGaebCheckPair(AFirst: TLandrixGaebXmlGAEB; const AFirstTarget: TLandrixGaebTarget;
  ASecond: TLandrixGaebXmlGAEB; const ASecondTarget: TLandrixGaebTarget;
  ADiagnostics: TLandrixGaebDiagnostics): Boolean;

implementation

uses
  LandrixGaebBoQTree;

const
  nkCtgy = LandrixGaebTreeCtgy;
  nkItem = LandrixGaebTreeItem;
  nkMarkup = LandrixGaebTreeMarkup;
  nkPerf = LandrixGaebTreePerf;

type
  TRuleNode = TLandrixGaebTreeNode;
  TKeyIndex = TLandrixGaebKeyIndex;

  { Collected structure of one document and the diagnostics of a run. }
  TRuleRun = class(TObject)
  private
    FDocument: TLandrixGaebXmlGAEB;
    FPhase: TLandrixGaebPhase;
    FTree: TLandrixGaebTree;
    FDiagnostics: TLandrixGaebDiagnostics;
    FErrors: Integer;
    FNodes: TObjectList;
    FRoot: TRuleNode;
    FInfoPath: TLandrixXmlUtf8;
    { breakdown: lengths and Num of the category levels, item, index }
    FHasBkdn: Boolean;
    FLevelLength: array of Integer;
    FLevelNum: array of Boolean;
    FItemLength: Integer;
    FItemNum: Boolean;
    FHasIndex: Boolean;
    procedure CheckBkdn;
    procedure CheckUPCompLabels;
    procedure CheckOZ;
    procedure CheckPart(R: TRuleNode; ALevel: Integer; const APart: TLandrixGaebString);
    procedure CheckItem83(R: TRuleNode; AItem: TLandrixGaebXmlItem);
    procedure CheckItem84(R: TRuleNode; AItem: TLandrixGaebXmlItem);
    procedure CheckReferences;
    procedure CheckPerfNumbers;
    procedure CheckTotals(ATotals: TLandrixGaebXmlTotals; const APath: TLandrixXmlUtf8);
    procedure CheckSums;
    procedure CategorySums(AFirst: TKeyIndex; const ARule: string);
  public
    constructor Create(ADocument: TLandrixGaebXmlGAEB; APhase: TLandrixGaebPhase;
      ADiagnostics: TLandrixGaebDiagnostics);
    destructor Destroy; override;
    function Applies(const ARuleId: string): Boolean;
    procedure Report(const ARuleId: string; const APath: TLandrixXmlUtf8; const AMessage: string);
    procedure Collect;
    procedure CheckAll;
    property Nodes: TObjectList read FNodes;
    property Root: TRuleNode read FRoot;
    property Errors: Integer read FErrors;
  end;

function LandrixGaebRuleIndex(const AID: string): Integer;
begin
  Result := LandrixGaebRuleCount - 1;
  while (Result >= 0) and (LandrixGaebRuleCatalog[Result].ID <> AID) do
    Dec(Result);
end;

function IntToUtf8(N: Integer): TLandrixXmlUtf8;
begin
  Result := LandrixXmlStringToUtf8(IntToStr(N));
end;

function GaebToStr(const S: TLandrixGaebString): string;
begin
  Result := LandrixXmlUtf8ToString(LandrixXmlWideToUtf8(S));
end;

function IntOf(const S: TLandrixGaebString; ADefault: Integer): Integer;
begin
  Result := StrToIntDef(Trim(GaebToStr(S)), ADefault);
end;

function XDec(const A: TLandrixGaebDecimal): TLandrixXmlDecimal;
begin
  Result := A.AsXmlDecimal;
end;

{ Amount in money: rounded to two fraction digits, half away from zero.
  DE: Geldbetrag: auf zwei Nachkommastellen kaufmaennisch gerundet. }
function Money(const A: TLandrixXmlDecimal): TLandrixXmlDecimal;
begin
  Result := LandrixGaebRoundHalfAwayFromZero(A, 2);
end;

function Same(const A, B: TLandrixXmlDecimal): Boolean;
begin
  Result := LandrixXmlDecimalCompare(A, B) = 0;
end;

{ Amount after a percentage discount: Money(AAmount * (1 - APcnt / 100)).
  DE: Betrag nach prozentualem Nachlass, kaufmaennisch auf Cent gerundet. }
function AfterDiscount(const AAmount, APcnt: TLandrixXmlDecimal): TLandrixXmlDecimal;
begin
  Result := Money(LandrixXmlDecimalSubtract(AAmount, LandrixXmlDecimalMultiplyPow10(
    LandrixXmlDecimalMultiply(AAmount, APcnt), -2)));
end;

{ True if S holds only '0', '_' or ' '. }
function OnlyFiller(const S: TLandrixGaebString): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to Length(S) do
    if (S[I] <> '0') and (S[I] <> '_') and (S[I] <> ' ') then
      Exit;
  Result := S <> '';
end;

{ Integer in canonical form (sign only if negative, no leading zeros) for
  any length; the text unchanged if it is no integer.
  DE: Ganzzahl in kanonischer Form (Vorzeichen nur bei negativen Zahlen,
  ohne fuehrende Nullen) fuer jede Laenge; der Text unveraendert, wenn er
  keine Ganzzahl ist. }
function CanonicalInteger(const S: TLandrixGaebString): TLandrixGaebString;
var
  T, Sign: TLandrixGaebString;
begin
  T := Trim(S);
  Sign := '';
  if (T <> '') and ((T[1] = '-') or (T[1] = '+')) then
  begin
    if T[1] = '-' then
      Sign := '-';
    T := Copy(T, 2, MaxInt);
  end;
  if not LandrixGaebIsDigits(T) then
  begin
    Result := S;
    Exit;
  end;
  T := LandrixGaebStripZeros(T);
  if T = '' then
    Result := '0'
  else
    Result := Sign + T;
end;

{ Numbers of the text complements in a text, at any depth (paragraphs,
  blocks, lists, tables).
  DE: Nummern der Textergaenzungen in einem Text in jeder Tiefe (Absaetze,
  Bloecke, Listen, Tabellen). }
procedure CollectComplements(ANode: TLandrixGaebXmlNode; AList: TStrings); forward;

procedure CollectChildren(AChildren: TLandrixGaebXmlNodeList; AList: TStrings);
var
  I: Integer;
begin
  for I := 0 to Integer(AChildren.Count) - 1 do
    CollectComplements(AChildren[I], AList);
end;

procedure CollectComplements(ANode: TLandrixGaebXmlNode; AList: TStrings);
var
  I: Integer;
begin
  if ANode is TLandrixGaebXmlTextComplement then
    AList.Add(GaebToStr(CanonicalInteger(TLandrixGaebXmlTextComplement(ANode).MarkLbl)))
  else if ANode is TLandrixGaebXmlBoQText then
    CollectChildren(TLandrixGaebXmlBoQText(ANode).Children, AList)
  else if ANode is TLandrixGaebXmlOutlTxt then
    CollectChildren(TLandrixGaebXmlOutlTxt(ANode).Children, AList)
  else if ANode is TLandrixGaebXmlFTextTC then
    CollectChildren(TLandrixGaebXmlFTextTC(ANode).Children, AList)
  else if ANode is TLandrixGaebXmlPTC then
    CollectChildren(TLandrixGaebXmlPTC(ANode).Children, AList)
  else if ANode is TLandrixGaebXmlDivTC then
    CollectChildren(TLandrixGaebXmlDivTC(ANode).Children, AList)
  else if ANode is TLandrixGaebXmlLiTC then
    CollectChildren(TLandrixGaebXmlLiTC(ANode).Children, AList)
  else if ANode is TLandrixGaebXmlTrTC then
    CollectChildren(TLandrixGaebXmlTrTC(ANode).Children, AList)
  else if ANode is TLandrixGaebXmlTdTC then
    CollectChildren(TLandrixGaebXmlTdTC(ANode).Children, AList)
  else if ANode is TLandrixGaebXmlUlTC then
  begin
    for I := 0 to Integer(TLandrixGaebXmlUlTC(ANode).Li.Count) - 1 do
      CollectComplements(TLandrixGaebXmlUlTC(ANode).Li[I], AList);
  end
  else if ANode is TLandrixGaebXmlOlTC then
  begin
    for I := 0 to Integer(TLandrixGaebXmlOlTC(ANode).Li.Count) - 1 do
      CollectComplements(TLandrixGaebXmlOlTC(ANode).Li[I], AList);
  end
  else if ANode is TLandrixGaebXmlTableTC then
  begin
    for I := 0 to Integer(TLandrixGaebXmlTableTC(ANode).Tr.Count) - 1 do
      CollectComplements(TLandrixGaebXmlTableTC(ANode).Tr[I], AList);
  end;
end;

{ Numbers of the text complements of a description in the long text and,
  with AOutline, also in the outline text (of CompleteText or standing
  alone); MarkLbl is an integer, so the numbers are normalised ("01" = "1").
  DE: Nummern der Textergaenzungen einer Beschreibung im Langtext und mit
  AOutline auch im Kurztext (in CompleteText oder allein); MarkLbl ist eine
  Ganzzahl, die Nummern werden daher normalisiert ("01" = "1"). }
procedure ComplementLabels(ADescription: TLandrixGaebXmlDescription; AList: TStrings;
  AOutline: Boolean);
begin
  if ADescription.HasCompleteText then
  begin
    if ADescription.CompleteText.HasDetailTxt then
      CollectComplements(ADescription.CompleteText.DetailTxt, AList);
    if AOutline and ADescription.CompleteText.HasOutlineText and
      ADescription.CompleteText.OutlineText.HasOutlTxt then
      CollectComplements(ADescription.CompleteText.OutlineText.OutlTxt, AList);
  end;
  if AOutline and ADescription.HasOutlineText and ADescription.OutlineText.HasOutlTxt then
    CollectComplements(ADescription.OutlineText.OutlTxt, AList);
end;

{ TRuleRun }

constructor TRuleRun.Create(ADocument: TLandrixGaebXmlGAEB; APhase: TLandrixGaebPhase;
  ADiagnostics: TLandrixGaebDiagnostics);
begin
  inherited Create;
  FDocument := ADocument;
  FPhase := APhase;
  FDiagnostics := ADiagnostics;
  FItemLength := -1;
end;

destructor TRuleRun.Destroy;
begin
  FTree.Free;
  inherited Destroy;
end;

function TRuleRun.Applies(const ARuleId: string): Boolean;
var
  I: Integer;
begin
  I := LandrixGaebRuleIndex(ARuleId);
  Result := (I >= 0) and (FPhase in LandrixGaebRuleCatalog[I].Phases);
end;

procedure TRuleRun.Report(const ARuleId: string; const APath: TLandrixXmlUtf8; const AMessage: string);
var
  I: Integer;
begin
  I := LandrixGaebRuleIndex(ARuleId);
  if (I < 0) or not (FPhase in LandrixGaebRuleCatalog[I].Phases) then
    Exit;
  if LandrixGaebRuleCatalog[I].Severity >= gsError then
    Inc(FErrors);
  if FDiagnostics <> nil then
    FDiagnostics.AddAt(ARuleId, LandrixGaebRuleCatalog[I].Severity, LandrixXmlUtf8ToWide(APath), 0, 0, -1,
      AMessage);
end;

procedure TRuleRun.Collect;
begin
  FTree := TLandrixGaebTree.Create(FDocument);
  FNodes := FTree.Nodes;
  FRoot := FTree.Root;
  FInfoPath := FTree.InfoPath;
end;

{ BKDN-001 to -004: the breakdown BoQBkdn itself (total length, order of
  the rows, index length, labels only for BoQLevel).
  DE: BKDN-001 bis -004: die Gliederung BoQBkdn selbst (Gesamtlaenge,
  Reihenfolge der Zeilen, Laenge des Index, Bezeichnung nur bei BoQLevel). }
procedure TRuleRun.CheckBkdn;
var
  Info: TLandrixGaebXmlBoQInfo;
  Row: TLandrixGaebXmlBoQBkdn;
  I, L, Sum, Lots, ItemRows, Indexes, Levels: Integer;
  Bad: Boolean;
  T: TLandrixGaebString;
  Path: TLandrixXmlUtf8;
begin
  FHasBkdn := False;
  if not FDocument.Award.BoQ.HasBoQInfo or not FDocument.Award.BoQ.BoQInfo.HasBoQBkdn then
    Exit;
  Info := FDocument.Award.BoQ.BoQInfo;
  FHasBkdn := True;
  Sum := 0;
  Lots := 0;
  ItemRows := 0;
  Indexes := 0;
  Levels := 0;
  Bad := False;
  for I := 0 to Integer(Info.BoQBkdn.Count) - 1 do
  begin
    Row := Info.BoQBkdn[I];
    Path := FInfoPath + '/BoQBkdn[' + IntToUtf8(I + 1) + ']';
    T := Row.TypeElement;
    L := IntOf(Row.LengthElement, 0);
    Inc(Sum, L);
    if (T = 'Lot') or (T = 'BoQLevel') then
    begin
      if (ItemRows > 0) or ((T = 'Lot') and ((I > 0) or (Lots > 0))) then
        Bad := True;
      if T = 'Lot' then
        Inc(Lots);
      Inc(Levels);
      SetLength(FLevelLength, Levels);
      SetLength(FLevelNum, Levels);
      FLevelLength[Levels - 1] := L;
      FLevelNum[Levels - 1] := Row.Num = 'Yes';
    end
    else if T = 'Item' then
    begin
      Inc(ItemRows);
      FItemLength := L;
      FItemNum := Row.Num = 'Yes';
    end
    else if T = 'Index' then
    begin
      if (ItemRows = 0) or (Indexes > 0) then
        Bad := True;
      Inc(Indexes);
      FHasIndex := True;
      if L <> 1 then
        Report('GAEB-BR-BKDN-003', Path, 'index of the breakdown must have length 1');
    end;
    if (Row.LblBoQBkdn <> '') and (T <> 'BoQLevel') then
      Report('GAEB-BR-BKDN-004', Path, 'label only allowed for a part of type BoQLevel');
  end;
  if (ItemRows <> 1) or (Levels > 5) then
    Bad := True;
  if Bad then
    Report('GAEB-BR-BKDN-002', FInfoPath, 'breakdown parts in wrong order or number');
  if Sum > 14 then
    Report('GAEB-BR-BKDN-001', FInfoPath, 'breakdown longer than 14 characters');
end;

{ UP-002: a label for each unit price component 1 to NoUPComps and none
  beyond.
  DE: UP-002: eine Bezeichnung fuer jeden EP-Anteil 1 bis NoUPComps und
  keine darueber hinaus. }
procedure TRuleRun.CheckUPCompLabels;
var
  Info: TLandrixGaebXmlBoQInfo;
  N, I: Integer;
  Has: array[1..6] of Boolean;
begin
  if not Applies('GAEB-BR-UP-002') or not FDocument.Award.BoQ.HasBoQInfo then
    Exit;
  Info := FDocument.Award.BoQ.BoQInfo;
  N := IntOf(Info.NoUPComps, 0);
  Has[1] := Info.HasLblUPComp1;
  Has[2] := Info.HasLblUPComp2;
  Has[3] := Info.HasLblUPComp3;
  Has[4] := Info.HasLblUPComp4;
  Has[5] := Info.HasLblUPComp5;
  Has[6] := Info.HasLblUPComp6;
  for I := 1 to 6 do
    if Has[I] <> (I <= N) then
    begin
          Report('GAEB-BR-UP-002', FInfoPath, 'unit price component labels do not match NoUPComps');
      Exit;
    end;
end;

{ OZ-003, OZ-005, OZ-006: one part of an OZ against its level of the
  breakdown (ALevel -1: the item level).
  DE: OZ-003, OZ-005, OZ-006: ein OZ-Teil gegen seine Stufe der Gliederung
  (ALevel -1: die Positionsstufe). }
procedure TRuleRun.CheckPart(R: TRuleNode; ALevel: Integer; const APart: TLandrixGaebString);
var
  MaxLen: Integer;
  Num: Boolean;
begin
  if OnlyFiller(APart) then
    Report('GAEB-BR-OZ-006', R.Path, 'part of the OZ made of zeros or underscores only');
  if not FHasBkdn then
    Exit;
  if ALevel < 0 then
  begin
    MaxLen := FItemLength;
    Num := FItemNum;
  end
  else if ALevel < Length(FLevelLength) then
  begin
    MaxLen := FLevelLength[ALevel];
    Num := FLevelNum[ALevel];
  end
  else
  begin
    Report('GAEB-BR-OZ-003', R.Path, 'category deeper than the levels of the breakdown');
    Exit;
  end;
  if MaxLen < 0 then
    Exit;
  if Length(APart) > MaxLen then
    Report('GAEB-BR-OZ-003', R.Path, 'part of the OZ longer than its level in the breakdown')
  else if (Length(APart) < MaxLen) and not (Num and LandrixGaebIsDigits(APart)) then
    Report('GAEB-BR-OZ-005', R.Path, 'part of the OZ shorter than its level in the breakdown');
end;

{ OZ-001 to -006 over all categories and items in document order.
  DE: OZ-001 bis -006 ueber alle Bereiche und Positionen in
  Dokumentreihenfolge. }
procedure TRuleRun.CheckOZ;
var
  I, Len, P: Integer;
  R, Last: TRuleNode;
  Keys, Ctgys: TKeyIndex;
begin
  Keys := TKeyIndex.Create;
  Ctgys := TKeyIndex.Create;
  try
    Last := nil;
    for I := 0 to Integer(FNodes.Count) - 1 do
    begin
      R := TRuleNode(FNodes[I]);
      if R.Kind = nkCtgy then
      begin
        CheckPart(R, Integer(Length(R.Parts)) - 1, R.Parts[High(R.Parts)]);
        Ctgys.Add(R.Key, R);
      end
      else if (R.Kind = nkItem) or (R.Kind = nkMarkup) then
      begin
        CheckPart(R, -1, R.Parts[High(R.Parts)]);
        if FHasBkdn and (R.Index <> '') and not FHasIndex then
          Report('GAEB-BR-OZ-003', R.Path, 'index although the breakdown has none');
        Len := Length(R.Index);
        for P := 0 to Integer(High(R.Parts)) do
          Inc(Len, Length(R.Parts[P]));
        if Len > 14 then
          Report('GAEB-BR-OZ-002', R.Path, 'OZ longer than 14 characters');
        if (Last <> nil) and (LandrixGaebCompareOZ(R, Last) < 0) then
          Report('GAEB-BR-OZ-004', R.Path, 'OZ lower than the OZ of the item before');
        Last := R;
        Keys.Add(R.Key, R);
      end;
    end;
    Keys.Sort;
    for I := 1 to Keys.Count - 1 do
      if Keys.Key(I) = Keys.Key(I - 1) then
        Report('GAEB-BR-OZ-001', Keys.Node(I).Path, 'OZ used before in the bill of quantities');
    Ctgys.Sort;
    for I := 1 to Ctgys.Count - 1 do
      if Ctgys.Key(I) = Ctgys.Key(I - 1) then
        Report('GAEB-BR-OZ-001', Ctgys.Node(I).Path, 'OZ of the category used before');
  finally
    Ctgys.Free;
    Keys.Free;
  end;
end;

{ Rules of a single item about quantities and texts (every phase but X84):
  QTY-001 to -006, ITEM-001/-002, TXT-004. QTY-002 only when every split gives a quantity (a split may give
  a percentage instead; the specification gives no rounding for it).
  DE: Regeln an einer Position zu Mengen und Texten (jede Phase ausser X84):
  QTY-001 bis -006, ITEM-001/-002, TXT-004. QTY-002 nur, wenn jede Aufteilung eine Menge
  angibt (statt dessen ist ein Prozentsatz zulaessig; dafuer legt die
  Spezifikation keine Rundung fest). }
procedure TRuleRun.CheckItem83(R: TRuleNode; AItem: TLandrixGaebXmlItem);
var
  I: Integer;
  Sum: TLandrixXmlDecimal;
  Labels: TStringList;
  AllQty: Boolean;
begin
  { X85: only items offered new or modified are transferred complete; the
    others (identical, also without AlterBidStatus, or not required) carry
    prices and bidder text complements as in X84 (documentation 4.6.15).
    DE: X85: nur neu oder geaendert angebotene Positionen werden komplett
    uebertragen; die anderen (identisch, auch ohne AlterBidStatus, oder
    nicht erforderlich) tragen wie in X84 Preise und
    Bietertextergaenzungen (Dokumentation 4.6.15). }
  if (FPhase = gp85) and (AItem.AlterBidStatus <> 'New') and (AItem.AlterBidStatus <> 'Modified') then
    Exit;
  if (AItem.QtyTBD = 'Yes') and AItem.HasQtySplit then
    Report('GAEB-BR-QTY-001', R.Path, 'QtySplit together with QtyTBD');
  if AItem.HasQtySplit and AItem.Qty.HasValue then
  begin
    Sum := LandrixXmlDecimalZero;
    AllQty := True;
    for I := 0 to Integer(AItem.QtySplit.Count) - 1 do
      if AItem.QtySplit[I].Qty.HasValue then
        Sum := LandrixXmlDecimalAdd(Sum, XDec(AItem.QtySplit[I].Qty))
      else
        AllQty := False;
    if AllQty and not Same(Sum, XDec(AItem.Qty)) then
      Report('GAEB-BR-QTY-002', R.Path, 'quantities of QtySplit do not add up to the quantity');
  end;
  if (AItem.QtyTBD = 'Yes') and AItem.Qty.HasValue then
    Report('GAEB-BR-QTY-003', R.Path, 'quantity together with QtyTBD');
  if not AItem.Qty.HasValue and (AItem.QtyTBD <> 'Yes') and (AItem.LumpSumItem <> 'Yes') then
    Report('GAEB-BR-QTY-004', R.Path, 'quantity missing');
  if (AItem.LumpSumItem = 'Yes') and (AItem.QtyTBD = 'Yes') then
    Report('GAEB-BR-QTY-005', R.Path, 'lump sum item with QtyTBD');
  if (AItem.LumpSumItem = 'Yes') and AItem.Qty.HasValue and
    not Same(XDec(AItem.Qty), LandrixXmlDecimalFromInt64(1)) then
    Report('GAEB-BR-QTY-006', R.Path, 'lump sum item with a quantity other than 1');
  if not AItem.HasDescription then
    Report('GAEB-BR-ITEM-001', R.Path, 'description missing');
  if (AItem.SumDescr = 'Yes') and not AItem.HasSubDescr and (AItem.RefDescr <> 'Rep') then
    Report('GAEB-BR-ITEM-002', R.Path, 'SumDescr without SubDescr');
  if AItem.HasDescription and AItem.Description.HasCompleteText then
  begin
    Labels := TStringList.Create;
    try
      { ComplTSA/ComplTSB concern the long text only }
      ComplementLabels(AItem.Description, Labels, False);
      if (Labels.Count > 0) and (AItem.Description.CompleteText.ComplTSA = '') and
        (AItem.Description.CompleteText.ComplTSB = '') then
        Report('GAEB-BR-TXT-004', R.Path, 'text complements without ComplTSA or ComplTSB');
    finally
      Labels.Free;
    end;
  end;
end;

{ Rules of a single item about prices (every phase but X83): UP-001, X84-001,
  SUM-001. A lump sum item without quantity counts with quantity 1. Items
  the document itself takes out of the totals (all but X84: alternative,
  eventual without total, not applicable) are not computed: their IT is 0
  or no total.
  DE: Regeln an einer Position zu Preisen (jede Phase ausser X83): UP-001, X84-001,
  SUM-001. Eine Pauschalposition ohne Menge zaehlt mit der Menge 1.
  Positionen, die das Dokument selbst aus den Summen nimmt (ausser X84:
  Alternative, Bedarf ohne GB, entfallend), werden nicht nachgerechnet: ihr
  IT ist 0 oder kein Gesamtbetrag. }
procedure TRuleRun.CheckItem84(R: TRuleNode; AItem: TLandrixGaebXmlItem);
var
  Sum, Total, Qty: TLandrixXmlDecimal;
  Any: Boolean;

  procedure AddComp(const A: TLandrixGaebDecimal);
  begin
    if A.HasValue then
    begin
      Sum := LandrixXmlDecimalAdd(Sum, XDec(A));
      Any := True;
    end;
  end;

begin
  Sum := LandrixXmlDecimalZero;
  Any := False;
  AddComp(AItem.UPComp1);
  AddComp(AItem.UPComp2);
  AddComp(AItem.UPComp3);
  AddComp(AItem.UPComp4);
  AddComp(AItem.UPComp5);
  AddComp(AItem.UPComp6);
  if Any and AItem.UP.HasValue and not Same(Sum, XDec(AItem.UP)) then
    Report('GAEB-BR-UP-001', R.Path, 'unit price components do not add up to the unit price');
  if (AItem.NotOffered = 'Yes') and AItem.UP.HasValue then
    Report('GAEB-BR-X84-001', R.Path, 'unit price of an item not offered');
  if (AItem.Qty.HasValue or (AItem.LumpSumItem = 'Yes')) and AItem.UP.HasValue and
    AItem.IT.HasValue and not LandrixGaebNotCounted(R) then
  begin
    if AItem.Qty.HasValue then
      Qty := XDec(AItem.Qty)
    else
      Qty := LandrixXmlDecimalFromInt64(1);
    Total := Money(LandrixXmlDecimalMultiply(Qty, XDec(AItem.UP)));
    if not Same(Total, XDec(AItem.IT)) and not (AItem.DiscountPcnt.HasValue and
      Same(AfterDiscount(Total, XDec(AItem.DiscountPcnt)), XDec(AItem.IT))) then
      Report('GAEB-BR-SUM-001', R.Path, 'total of the item differs from quantity times unit price');
  end;
end;

{ TXT-001 to -003 and PERF-002: references of repetition descriptions and
  of execution descriptions.
  DE: TXT-001 bis -003 und PERF-002: Bezuege von Wiederholungs- und
  Ausfuehrungsbeschreibungen. }
procedure TRuleRun.CheckReferences;
var
  Ids, Perfs: TKeyIndex;
  I: Integer;
  R, T: TRuleNode;
  Item: TLandrixGaebXmlItem;
begin
  Ids := TKeyIndex.Create;
  Perfs := TKeyIndex.Create;
  try
    for I := 0 to Integer(FNodes.Count) - 1 do
    begin
      R := TRuleNode(FNodes[I]);
      if R.Kind = nkItem then
        Ids.Add(TLandrixGaebXmlItem(R.Node).ID, R)
      else if R.Kind = nkPerf then
        Perfs.Add(TLandrixGaebXmlPerfDescr(R.Node).ID, R);
    end;
    Ids.Sort;
    Perfs.Sort;
    for I := 0 to Integer(FNodes.Count) - 1 do
    begin
      R := TRuleNode(FNodes[I]);
      if R.Kind <> nkItem then
        Continue;
      Item := TLandrixGaebXmlItem(R.Node);
      if Item.RefDescr = 'Rep' then
      begin
        T := nil;
        if Item.HasRefRNo then
          T := Ids.Find(Item.RefRNo.IDRef);
        if (T = nil) or (TLandrixGaebXmlItem(T.Node).RefDescr = 'Rep') then
          Report('GAEB-BR-TXT-001', R.Path, 'repetition description without reference description')
        else
        begin
          if T.Order > R.Order then
            Report('GAEB-BR-TXT-003', R.Path, 'reference description after its repetition');
          if TLandrixGaebXmlItem(T.Node).QU <> Item.QU then
            Report('GAEB-BR-TXT-002', R.Path, 'unit differs from the reference description');
        end;
      end;
      if Item.HasRefPerfNo then
      begin
        T := Perfs.Find(Item.RefPerfNo.IDRef);
        if (T <> nil) and (T.Order > R.Order) then
          Report('GAEB-BR-PERF-002', R.Path, 'execution description after the item');
      end;
    end;
  finally
    Perfs.Free;
    Ids.Free;
  end;
end;

{ PERF-001: numbers of execution descriptions unique (by value).
  DE: PERF-001: Nummern der Ausfuehrungsbeschreibungen eindeutig (nach
  Wert). }
procedure TRuleRun.CheckPerfNumbers;
var
  Keys: TKeyIndex;
  I: Integer;
  R: TRuleNode;
begin
  Keys := TKeyIndex.Create;
  try
    for I := 0 to Integer(FNodes.Count) - 1 do
    begin
      R := TRuleNode(FNodes[I]);
      if R.Kind = nkPerf then
        Keys.Add(LandrixXmlUtf8ToWide(LandrixXmlStringToUtf8(
          IntToStr(IntOf(TLandrixGaebXmlPerfDescr(R.Node).PerfNo, -1)))), R);
    end;
    Keys.Sort;
    for I := 1 to Keys.Count - 1 do
      if Keys.Key(I) = Keys.Key(I - 1) then
        Report('GAEB-BR-PERF-001', Keys.Node(I).Path, 'number of the execution description used before');
  finally
    Keys.Free;
  end;
end;

{ SUM-002: TotAfterDisc follows from Total and DiscountPcnt or DiscountAmt.
  DE: SUM-002: TotAfterDisc ergibt sich aus Total und DiscountPcnt bzw.
  DiscountAmt. }
procedure TRuleRun.CheckTotals(ATotals: TLandrixGaebXmlTotals; const APath: TLandrixXmlUtf8);
var
  Path: TLandrixXmlUtf8;
begin
  if not ATotals.Total.HasValue then
    Exit;
  Path := APath + '/Totals[1]';
  if (ATotals.DiscountPcnt.HasValue or ATotals.DiscountAmt.HasValue) and
    not ATotals.TotAfterDisc.HasValue then
    Report('GAEB-BR-SUM-002', Path, 'discount without TotAfterDisc')
  else if ATotals.DiscountPcnt.HasValue and
    not Same(AfterDiscount(XDec(ATotals.Total), XDec(ATotals.DiscountPcnt)), XDec(ATotals.TotAfterDisc)) then
    Report('GAEB-BR-SUM-002', Path, 'TotAfterDisc differs from the total after the percentage discount')
  else if ATotals.DiscountAmt.HasValue and
    not Same(LandrixXmlDecimalSubtract(XDec(ATotals.Total), XDec(ATotals.DiscountAmt)),
    XDec(ATotals.TotAfterDisc)) then
    Report('GAEB-BR-SUM-002', Path, 'TotAfterDisc differs from total minus DiscountAmt');
end;

{ SUM-002: the totals blocks themselves (TotAfterDisc).
  DE: SUM-002: die Summenbloecke selbst (TotAfterDisc). }
procedure TRuleRun.CheckSums;
var
  I: Integer;
  R: TRuleNode;
begin
  for I := 0 to Integer(FNodes.Count) - 1 do
  begin
    R := TRuleNode(FNodes[I]);
    if (R.Kind = nkCtgy) and TLandrixGaebXmlBoQCtgy(R.Node).HasTotals then
      CheckTotals(TLandrixGaebXmlBoQCtgy(R.Node).Totals, R.Path);
  end;
  if FDocument.Award.BoQ.HasBoQInfo and FDocument.Award.BoQ.BoQInfo.HasTotals then
    CheckTotals(FDocument.Award.BoQ.BoQInfo.Totals, FInfoPath);
end;

{ The totals of the categories and of the bill against the sums of their
  counting children (ARule). The kinds that take a node out of the totals
  come from AFirst (the index of the request, PAIR-83-84-008) or, without
  it, from the document itself (SUM-003); there a node with
  Accepted makes the sum of its parent unknown.
  DE: Die Summen der Bereiche und des LV gegen die Summe ihrer zaehlenden
  Kinder (ARule). Die Kennzeichen, die einen Knoten aus den Summen nehmen,
  kommen aus AFirst (Index der Anfrage, PAIR-83-84-008) oder ohne ihn aus
  dem Dokument selbst (SUM-003); dort macht ein Knoten mit
  Accepted die Summe seines Elternknotens unbekannt. }
procedure TRuleRun.CategorySums(AFirst: TKeyIndex; const ARule: string);
var
  I: Integer;
  R, Kinds: TRuleNode;
  Amount: TLandrixXmlDecimal;
  Known: Boolean;
  Ctgy: TLandrixGaebXmlBoQCtgy;
  Info: TLandrixGaebXmlBoQInfo;
begin
  for I := 0 to Integer(FNodes.Count) - 1 do
  begin
    R := TRuleNode(FNodes[I]);
    if not (R.Kind in [nkItem, nkMarkup, nkCtgy]) then
      Continue;
    if AFirst <> nil then
      Kinds := AFirst.Find(LandrixGaebMatchKey(R))
    else
    begin
      Kinds := R;
      if LandrixGaebHasAccepted(R) then
      begin
        R.Parent.SumKnown := False;
        Continue;
      end;
    end;
    Known := LandrixGaebNodeAmount(R, Amount);
    { nodes the request takes out of the totals do not count; an item not
      offered counts 0; any other node without an amount makes the sum of
      its parent unknown }
    if LandrixGaebNotCounted(Kinds) then
      Continue;
    if Known then
      R.Parent.Sum := LandrixXmlDecimalAdd(R.Parent.Sum, Amount)
    else if not ((R.Kind = nkItem) and (TLandrixGaebXmlItem(R.Node).NotOffered = 'Yes')) then
      R.Parent.SumKnown := False;
  end;
  for I := 0 to Integer(FNodes.Count) - 1 do
  begin
    R := TRuleNode(FNodes[I]);
    if R.Kind <> nkCtgy then
      Continue;
    Ctgy := TLandrixGaebXmlBoQCtgy(R.Node);
    if R.SumKnown and Ctgy.HasTotals and Ctgy.Totals.Total.HasValue and
      not Same(R.Sum, XDec(Ctgy.Totals.Total)) then
      Report(ARule, R.Path + '/Totals[1]', 'total differs from the sum of the category');
  end;
  if FDocument.Award.BoQ.HasBoQInfo then
  begin
    Info := FDocument.Award.BoQ.BoQInfo;
    if Info.HasTotals and FRoot.SumKnown and Info.Totals.Total.HasValue and
      not Same(FRoot.Sum, XDec(Info.Totals.Total)) then
      Report(ARule, FInfoPath + '/Totals[1]', 'total differs from the sum of the bill of quantities');
  end;
end;

{ All rules of one document. MKUP-001: MarkupSubQty exactly with
  MarkupType ListInSubQty.
  DE: Alle Regeln eines Dokuments. MKUP-001: MarkupSubQty genau bei
  MarkupType ListInSubQty. }
procedure TRuleRun.CheckAll;
var
  I: Integer;
  R: TRuleNode;
  Markup: TLandrixGaebXmlMarkupItem;
begin
  if not FDocument.HasAward or not FDocument.Award.HasBoQ then
    Exit;
  CheckBkdn;
  CheckUPCompLabels;
  CheckOZ;
  CheckReferences;
  CheckPerfNumbers;
  for I := 0 to Integer(FNodes.Count) - 1 do
  begin
    R := TRuleNode(FNodes[I]);
    if R.Kind = nkItem then
    begin
      { the catalog decides per phase which of these rules report: X80 to
        X82 and X85 to X87 carry both the request's structure and prices }
      CheckItem83(R, TLandrixGaebXmlItem(R.Node));
      CheckItem84(R, TLandrixGaebXmlItem(R.Node));
    end
    else if R.Kind = nkMarkup then
    begin
      Markup := TLandrixGaebXmlMarkupItem(R.Node);
      if (Markup.MarkupType = 'ListInSubQty') <> Markup.HasMarkupSubQty then
        Report('GAEB-BR-MKUP-001', R.Path, 'MarkupSubQty does not fit MarkupType');
    end;
  end;
  CheckSums;
  if Applies('GAEB-BR-SUM-003') then
    CategorySums(nil, 'GAEB-BR-SUM-003');
end;

function LandrixGaebCheckRules(ADocument: TLandrixGaebXmlGAEB; const ATarget: TLandrixGaebTarget;
  ADiagnostics: TLandrixGaebDiagnostics): Boolean;
var
  Run: TRuleRun;
begin
  Run := TRuleRun.Create(ADocument, ATarget.Phase, ADiagnostics);
  try
    Run.Collect;
    Run.CheckAll;
    Result := Run.Errors = 0;
  finally
    Run.Free;
  end;
end;

{ ---- pair rules ---- }

type
  TPairRun = class(TObject)
  private
    FFirst, FSecond: TRuleRun;
    FFirstDoc, FSecondDoc: TLandrixGaebXmlGAEB;
    procedure Fill(ARun: TRuleRun; AKeys: TKeyIndex);
  public
    constructor Create(AFirst: TLandrixGaebXmlGAEB; AFirstPhase: TLandrixGaebPhase;
      ASecond: TLandrixGaebXmlGAEB; ASecondPhase: TLandrixGaebPhase; ADiagnostics: TLandrixGaebDiagnostics);
    destructor Destroy; override;
    procedure Check83_84;
    procedure CheckSame(const AStructure, APrice, AQuantity: string);
    function Errors: Integer;
  end;

constructor TPairRun.Create(AFirst: TLandrixGaebXmlGAEB; AFirstPhase: TLandrixGaebPhase;
  ASecond: TLandrixGaebXmlGAEB; ASecondPhase: TLandrixGaebPhase; ADiagnostics: TLandrixGaebDiagnostics);
begin
  inherited Create;
  FFirstDoc := AFirst;
  FSecondDoc := ASecond;
  { the pair rules are listed for the phase of the second document; the
    first run only collects }
  FFirst := TRuleRun.Create(AFirst, AFirstPhase, nil);
  FSecond := TRuleRun.Create(ASecond, ASecondPhase, ADiagnostics);
  FFirst.Collect;
  FSecond.Collect;
end;

destructor TPairRun.Destroy;
begin
  FSecond.Free;
  FFirst.Free;
  inherited Destroy;
end;

function TPairRun.Errors: Integer;
begin
  Result := FSecond.Errors;
end;

{ Categories, items and markup items of a document by key (OZ).
  DE: Bereiche, Positionen und Zuschlagspositionen eines Dokuments nach
  Schluessel (OZ). }
procedure TPairRun.Fill(ARun: TRuleRun; AKeys: TKeyIndex);
var
  K: Integer;
  N: TRuleNode;
begin
  for K := 0 to Integer(ARun.Nodes.Count) - 1 do
  begin
    N := TRuleNode(ARun.Nodes[K]);
    if N.Kind in [nkCtgy, nkItem, nkMarkup] then
      AKeys.Add(LandrixGaebMatchKey(N), N);
  end;
  AKeys.Sort;
end;

{ PAIR-83-84-001 to -008: the bid against its request, matched by OZ.
  DE: PAIR-83-84-001 bis -008: das Angebot gegen seine Anfrage, zugeordnet
  ueber die OZ. }
procedure TPairRun.Check83_84;
var
  FirstKeys, SecondKeys: TKeyIndex;
  I, J, Digits, NoComps: Integer;
  R, M: TRuleNode;
  A, B: TLandrixGaebXmlItem;
  Qty, Total: TLandrixXmlDecimal;
  FirstLabels, SecondLabels: TStringList;

  function RuleOf(ANode: TRuleNode): string;
  begin
    if ANode.Kind = nkCtgy then
      Result := 'GAEB-BR-PAIR-83-84-002'
    else
      Result := 'GAEB-BR-PAIR-83-84-001';
  end;

  { Significant digits count: '12.500' has two (the writer pads unit
    prices to the three digits of the schema type).
    DE: Es zaehlen werttragende Stellen: '12.500' hat zwei (der Schreiber
    fuellt Einheitspreise auf die drei Stellen des Schematyps auf). }
  procedure CheckDigits(const AValue: TLandrixGaebDecimal; const APath: TLandrixXmlUtf8);
  var
    Text: TLandrixXmlUtf8;
  begin
    if (Digits >= 0) and AValue.HasValue and not AValue.TryTextWithScale(Digits, Text) then
      FSecond.Report('GAEB-BR-PAIR-83-84-003', APath, 'unit price with more significant fraction digits than UPFracDig');
  end;

  procedure CheckComp(const AValue: TLandrixGaebDecimal; ANumber: Integer; const APath: TLandrixXmlUtf8);
  begin
    CheckDigits(AValue, APath);
    if (NoComps >= 0) and (ANumber > NoComps) and AValue.HasValue then
      FSecond.Report('GAEB-BR-PAIR-83-84-005', APath, 'unit price component beyond NoUPComps of the request');
  end;

  { PAIR-83-84-003 and -005 for the prices of the item and of its sub
    descriptions, which carry the same elements.
    DE: PAIR-83-84-003 und -005 fuer die Preise der Position und ihrer
    Unterbeschreibungen, die dieselben Elemente tragen. }
  procedure CheckPrices(AItem: TLandrixGaebXmlItem; const APath: TLandrixXmlUtf8);
  var
    K: TLandrixGaebListIndex;
    Sub: TLandrixGaebXmlSubDescr;
    SubPath: TLandrixXmlUtf8;
  begin
    CheckDigits(AItem.UP, APath);
    CheckComp(AItem.UPComp1, 1, APath);
    CheckComp(AItem.UPComp2, 2, APath);
    CheckComp(AItem.UPComp3, 3, APath);
    CheckComp(AItem.UPComp4, 4, APath);
    CheckComp(AItem.UPComp5, 5, APath);
    CheckComp(AItem.UPComp6, 6, APath);
    if not AItem.HasSubDescr then
      Exit;
    for K := 0 to AItem.SubDescr.Count - 1 do
    begin
      Sub := AItem.SubDescr[K];
      SubPath := APath + '/SubDescr[' + IntToUtf8(Integer(K) + 1) + ']';
      CheckDigits(Sub.UP, SubPath);
      CheckComp(Sub.UPComp1, 1, SubPath);
      CheckComp(Sub.UPComp2, 2, SubPath);
      CheckComp(Sub.UPComp3, 3, SubPath);
      CheckComp(Sub.UPComp4, 4, SubPath);
      CheckComp(Sub.UPComp5, 5, SubPath);
      CheckComp(Sub.UPComp6, 6, SubPath);
    end;
  end;

begin
  FirstKeys := TKeyIndex.Create;
  SecondKeys := TKeyIndex.Create;
  FirstLabels := TStringList.Create;
  SecondLabels := TStringList.Create;
  try
    Fill(FFirst, FirstKeys);
    Fill(FSecond, SecondKeys);
    for I := 0 to FirstKeys.Count - 1 do
    begin
      R := FirstKeys.Node(I);
      if SecondKeys.Find(FirstKeys.Key(I)) = nil then
        FSecond.Report(RuleOf(R), R.Path, 'element of the first document (path there) missing in the second');
    end;
    for I := 0 to SecondKeys.Count - 1 do
    begin
      R := SecondKeys.Node(I);
      M := FirstKeys.Find(SecondKeys.Key(I));
      if M = nil then
        FSecond.Report(RuleOf(R), R.Path, 'element not in the first document')
      else if M.Kind <> R.Kind then
        FSecond.Report(RuleOf(R), R.Path, 'item and markup item swapped against the first document');
    end;
    Digits := -1;
    if FFirstDoc.HasPrjInfo then
    begin
      Digits := IntOf(FFirstDoc.PrjInfo.UPFracDig, -1);
      { only the values of the schema (2, 3); others are found by the check
        (stage 2) and would make TryTextWithScale build huge strings
        DE: nur die Werte des Schemas (2, 3); andere findet die Pruefung
        (Stufe 2), sie liessen TryTextWithScale riesige Texte bauen }
      if (Digits < 2) or (Digits > 3) then
        Digits := -1;
    end;
    NoComps := -1;
    if FFirstDoc.HasAward and FFirstDoc.Award.HasBoQ and FFirstDoc.Award.BoQ.HasBoQInfo then
      NoComps := IntOf(FFirstDoc.Award.BoQ.BoQInfo.NoUPComps, -1);
    for I := 0 to SecondKeys.Count - 1 do
    begin
      R := SecondKeys.Node(I);
      if R.Kind <> nkItem then
        Continue;
      M := FirstKeys.Find(SecondKeys.Key(I));
      if (M = nil) or (M.Kind <> nkItem) then
        Continue;
      A := TLandrixGaebXmlItem(M.Node);
      B := TLandrixGaebXmlItem(R.Node);
      CheckPrices(B, R.Path);
      if B.Qty.HasValue and (A.QtyTBD <> 'Yes') then
        FSecond.Report('GAEB-BR-PAIR-83-84-006', R.Path, 'quantity for an item without QtyTBD in the request');
      { alternatives and eventual items without total carry an IT that is
        no total (official test files: 0.00 or the product) }
      if B.UP.HasValue and B.IT.HasValue and
        (B.Qty.HasValue or A.Qty.HasValue or (A.LumpSumItem = 'Yes')) and not LandrixGaebNotCounted(M) then
      begin
        { a lump sum item without quantity counts with quantity 1 }
        if B.Qty.HasValue then
          Qty := XDec(B.Qty)
        else if A.Qty.HasValue then
          Qty := XDec(A.Qty)
        else
          Qty := LandrixXmlDecimalFromInt64(1);
        Total := Money(LandrixXmlDecimalMultiply(Qty, XDec(B.UP)));
        if not Same(Total, XDec(B.IT)) and not (B.DiscountPcnt.HasValue and
          Same(AfterDiscount(Total, XDec(B.DiscountPcnt)), XDec(B.IT))) then
          FSecond.Report('GAEB-BR-PAIR-83-84-004', R.Path,
            'total of the item differs from the quantity of the request times the unit price');
      end;
      if B.HasDescription then
      begin
        FirstLabels.Clear;
        SecondLabels.Clear;
        if A.HasDescription then
          ComplementLabels(A.Description, FirstLabels, True);
        ComplementLabels(B.Description, SecondLabels, True);
        for J := 0 to SecondLabels.Count - 1 do
          if FirstLabels.IndexOf(SecondLabels[J]) < 0 then
          begin
            FSecond.Report('GAEB-BR-PAIR-83-84-007', R.Path, 'text complement number not in the request');
            Break;
          end;
      end;
    end;
    if FSecondDoc.HasAward and FSecondDoc.Award.HasBoQ then
      FSecond.CategorySums(FirstKeys, 'GAEB-BR-PAIR-83-84-008');
  finally
    SecondLabels.Free;
    FirstLabels.Free;
    SecondKeys.Free;
    FirstKeys.Free;
  end;
end;

{ PAIR-84-86-001 to -003 and PAIR-86-87-001 to -003 (warnings): the award
  against the bid, the confirmation against the award, matched by OZ: the
  same items and categories (AStructure), unit prices (APrice) and
  quantities (AQuantity).
  DE: PAIR-84-86-001 bis -003 und PAIR-86-87-001 bis -003 (Warnungen): der
  Auftrag gegen das Angebot, die Bestaetigung gegen den Auftrag, zugeordnet
  ueber die OZ: dieselben Positionen und Bereiche (AStructure),
  Einheitspreise (APrice) und Mengen (AQuantity). }
procedure TPairRun.CheckSame(const AStructure, APrice, AQuantity: string);
var
  FirstKeys, SecondKeys: TKeyIndex;
  I: Integer;
  R, M: TRuleNode;
  A, B: TLandrixGaebXmlItem;
begin
  FirstKeys := TKeyIndex.Create;
  SecondKeys := TKeyIndex.Create;
  try
    Fill(FFirst, FirstKeys);
    Fill(FSecond, SecondKeys);
    for I := 0 to FirstKeys.Count - 1 do
      if SecondKeys.Find(FirstKeys.Key(I)) = nil then
        FSecond.Report(AStructure, FirstKeys.Node(I).Path,
          'element of the first document (path there) missing in the second');
    for I := 0 to SecondKeys.Count - 1 do
    begin
      R := SecondKeys.Node(I);
      M := FirstKeys.Find(SecondKeys.Key(I));
      if M = nil then
        FSecond.Report(AStructure, R.Path, 'element not in the first document')
      else if M.Kind <> R.Kind then
        FSecond.Report(AStructure, R.Path, 'item and markup item swapped against the first document')
      else if R.Kind = nkItem then
      begin
        A := TLandrixGaebXmlItem(M.Node);
        B := TLandrixGaebXmlItem(R.Node);
        if A.UP.HasValue and B.UP.HasValue and not Same(XDec(A.UP), XDec(B.UP)) then
          FSecond.Report(APrice, R.Path, 'unit price differs from the first document');
        if A.Qty.HasValue and B.Qty.HasValue and not Same(XDec(A.Qty), XDec(B.Qty)) then
          FSecond.Report(AQuantity, R.Path, 'quantity differs from the first document');
      end;
    end;
  finally
    SecondKeys.Free;
    FirstKeys.Free;
  end;
end;

function LandrixGaebCheckPair(AFirst: TLandrixGaebXmlGAEB; const AFirstTarget: TLandrixGaebTarget;
  ASecond: TLandrixGaebXmlGAEB; const ASecondTarget: TLandrixGaebTarget;
  ADiagnostics: TLandrixGaebDiagnostics): Boolean;
var
  Run: TPairRun;
begin
  if not ((AFirstTarget.Phase = gp83) and (ASecondTarget.Phase = gp84)) and
    not ((AFirstTarget.Phase = gp84) and (ASecondTarget.Phase = gp86)) and
    not ((AFirstTarget.Phase = gp86) and (ASecondTarget.Phase = gp87)) then
    raise ELandrixGaebError.Create('no pair rules for DA' +
      LandrixXmlUtf8ToString(LandrixGaebPhaseToDP(AFirstTarget.Phase)) + ' and DA' +
      LandrixXmlUtf8ToString(LandrixGaebPhaseToDP(ASecondTarget.Phase)));
  Run := TPairRun.Create(AFirst, AFirstTarget.Phase, ASecond, ASecondTarget.Phase, ADiagnostics);
  try
    if ASecondTarget.Phase = gp84 then
      Run.Check83_84
    else if ASecondTarget.Phase = gp86 then
      Run.CheckSame('GAEB-BR-PAIR-84-86-001', 'GAEB-BR-PAIR-84-86-002', 'GAEB-BR-PAIR-84-86-003')
    else
      Run.CheckSame('GAEB-BR-PAIR-86-87-001', 'GAEB-BR-PAIR-86-87-002', 'GAEB-BR-PAIR-86-87-003');
    Result := Run.Errors = 0;
  finally
    Run.Free;
  end;
end;

end.
