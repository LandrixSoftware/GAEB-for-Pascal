{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Basic types shared by all units: the library version, the string type,
  the exception base class, the GAEB DA XML target (version, schema edition,
  exchange phase) and the decimal value types.

  DE: Grundtypen fuer alle Units: Bibliotheksversion, Zeichenkettentyp,
  Basisklasse der Ausnahmen, das GAEB-DA-XML-Ziel (Version, Schema-Ausgabe,
  Austauschphase) und die Dezimal-Werttypen.

  String type
  -----------
  TLandrixGaebString is UTF-16 and lossless on every compiler, the same type
  as TLandrixXmlWide (Delphi 6-2007: WideString, Delphi 2009+: string,
  FPC: UnicodeString). Assigning it to a plain string loses characters on
  Delphi 6-2007 and FPC.

  DE: TLandrixGaebString ist auf jedem Compiler UTF-16 und verlustfrei,
  derselbe Typ wie TLandrixXmlWide (Delphi 6-2007: WideString, ab Delphi
  2009: string, FPC: UnicodeString). Die Zuweisung an einen normalen string
  verliert unter Delphi 6-2007 und FPC Zeichen.

  Decimal types
  -------------
  TLandrixGaebDecimal holds the bounded GAEB decimal types (tgDecimal_n_m,
  quantities, prices): an Int64 coefficient with a scale, so 12.500 keeps
  its three fraction digits. TLandrixGaebDecimalText holds the unbounded
  tgDecimal as validated text. Neither ever goes through floating point.

  DE: TLandrixGaebDecimal nimmt die begrenzten GAEB-Dezimaltypen auf
  (tgDecimal_n_m, Mengen, Preise): ein Int64-Koeffizient mit Skala, damit
  12.500 seine drei Nachkommastellen behaelt. TLandrixGaebDecimalText nimmt
  das unbegrenzte tgDecimal als geprueften Text auf. Beide laufen nie ueber
  Gleitkommazahlen. }

{ API: stable. Covered by semantic versioning from release 1.0 on.
  DE: API: stabil. Ab Version 1.0 durch die semantische Versionierung
  abgedeckt. }

unit LandrixGaebTypes;

{$I LandrixGaeb.inc}

interface

uses
  SysUtils,
  LandrixXmlBase,
  LandrixXmlDecimal;

const
  { Library version (Semantic Versioning).
    DE: Version der Bibliothek (Semantic Versioning). }
  LandrixGaebLibraryVersion = '1.2.0';

  { Largest scale (fraction digits) of TLandrixGaebDecimal.
    DE: Groesste Skala (Nachkommastellen) von TLandrixGaebDecimal. }
  LandrixGaebDecimalMaxScale = 18;

  { Largest absolute coefficient of TLandrixGaebDecimal (18 digits).
    DE: Groesster Betrag des Koeffizienten von TLandrixGaebDecimal
    (18 Ziffern). }
  LandrixGaebDecimalMaxCoefficient = 999999999999999999;

type
{$IFDEF FPC}
  TLandrixGaebString = UnicodeString;
{$ELSE}
  {$IFDEF LANDRIXGAEB_UNICODE}
  TLandrixGaebString = string;
  {$ELSE}
  TLandrixGaebString = WideString;
  {$ENDIF}
{$ENDIF}
  TLandrixGaebChar = WideChar;

  { Index type of the library's list classes (TObjectList descendants); it
    matches the index type of TList on each compiler: NativeInt on Delphi
    12 and later (the only use of NativeInt in the library), else Integer.
    DE: Indextyp der Listenklassen (Nachfahren von TObjectList); entspricht
    dem Indextyp von TList je Compiler: NativeInt ab Delphi 12 (die einzige
    Verwendung von NativeInt in der Bibliothek), sonst Integer. }
{$IFDEF FPC}
  TLandrixGaebListIndex = Integer;
{$ELSE}
  {$IF CompilerVersion >= 36.0}
  TLandrixGaebListIndex = NativeInt; // check-forbidden: allow
  {$ELSE}
  TLandrixGaebListIndex = Integer;
  {$IFEND}
{$ENDIF}

  { Base class of the library's own exceptions (errors from LandrixXml keep
    their class ELandrixXmlError).
    DE: Basisklasse der eigenen Ausnahmen (Fehler aus LandrixXml behalten
    ihre Klasse ELandrixXmlError). }
  ELandrixGaebError = class(Exception);

  { GAEB DA XML version. Later releases add values: handle
    unknown values in an else branch and do not store ordinal values.
    DE: Version von GAEB DA XML. Spaetere Versionen ergaenzen Werte:
    unbekannte Werte in einem else-Zweig behandeln, keine Ordinalwerte
    speichern. }
  TLandrixGaebVersion = (gvUnknown, gv30, gv31, gv32, gv33, gv34);

  { Schema edition: VersDate, or the publication date of the schema set.
    Later releases add values: handle
    unknown values in an else branch and do not store ordinal values.
    DE: Schema-Ausgabe: VersDate bzw. Erscheinungsdatum des Schemasatzes.
    Spaetere Versionen ergaenzen Werte:
    unbekannte Werte in einem else-Zweig behandeln, keine Ordinalwerte
    speichern. }
  TLandrixGaebEdition = (geUnknown, ge2004_07, ge2007_11, ge2009_12, ge2013_10,
    ge2014_03, ge2019_11, ge2021_05, ge2023_01, ge2026_03);

  { Exchange phase (DP). gp50_1 is DP '50.1' and so on. 50 and 51 alone are
    no exchange phases (base schemas without root element).
    Later releases add values: handle
    unknown values in an else branch and do not store ordinal values.
    DE: Austauschphase (DP). gp50_1 ist DP '50.1' usw. 50 und 51 allein sind
    keine Austauschphasen (Basisschemas ohne Wurzelelement).
    Spaetere Versionen ergaenzen Werte:
    unbekannte Werte in einem else-Zweig behandeln, keine Ordinalwerte
    speichern. }
  TLandrixGaebPhase = (gpUnknown, gp31, gp50_1, gp50_2, gp51_1,
    gp51_2, gp52, gp61, gp80, gp81, gp82, gp83, gp83Z, gp84, gp84P, gp84Z,
    gp85, gp86, gp86ZE, gp86ZR, gp87, gp88, gp89, gp89B, gp93, gp94, gp96,
    gp97, gp98, gp99);
  TLandrixGaebPhases = set of TLandrixGaebPhase;

  { Character set declared in a GAEB DA 2000 file (GAEBInfo/Zeichensatz):
    gcsUnknown when the file does not declare one or declares an unknown
    one. A declaration, not proof of the byte encoding: the reader decides
    how to decode. Later releases add values: handle unknown values in an
    else branch and do not store ordinal values.
    DE: In einer GAEB-DA-2000-Datei angegebener Zeichensatz
    (GAEBInfo/Zeichensatz): gcsUnknown, wenn die Datei keinen oder einen
    unbekannten angibt. Eine Angabe, kein Nachweis der Byte-Codierung: wie
    dekodiert wird, entscheidet der Leser. Spaetere Versionen ergaenzen
    Werte: unbekannte Werte in einem else-Zweig behandeln, keine
    Ordinalwerte speichern. }
  TLandrixGaebCharset = (gcsUnknown, gcsAnsi, gcsOem, gcsUnicode);

  { Target of a read, check or write: version, schema edition and exchange
    phase. A record without methods (Delphi 6).
    DE: Ziel eines Lese-, Pruef- oder Schreibvorgangs: Version,
    Schema-Ausgabe und Austauschphase. Record ohne Methoden (Delphi 6). }
  TLandrixGaebTarget = record
    Version: TLandrixGaebVersion;
    Edition: TLandrixGaebEdition;
    Phase: TLandrixGaebPhase;
  end;

  { Bounded decimal value (tgDecimal_n_m, quantities, prices): Int64
    coefficient and scale, Value = Coefficient / 10^Scale. The scale is
    kept as read (12.500 has scale 3); Equals compares values, not scales.
    Zeroed memory means "not set". Old-style object without VMT; its size
    must not be 8 bytes (Delphi 13 Win64 passes such objects wrongly).
    DE: Begrenzter Dezimalwert (tgDecimal_n_m, Mengen, Preise):
    Int64-Koeffizient und Skala, Wert = Koeffizient / 10^Skala. Die Skala
    bleibt wie gelesen erhalten (12.500 hat Skala 3); Equals vergleicht
    Werte, nicht Skalen. Nullspeicher bedeutet "nicht gesetzt". Object ohne
    VMT; seine Groesse darf nicht 8 Byte sein (Delphi 13 Win64 uebergibt
    solche Objects falsch). }
  TLandrixGaebDecimal = object
  private
    FCoefficient: Int64;
    FScale: Integer;
    FHasValue: Boolean;
  public
    procedure Clear;
    function HasValue: Boolean;
    { Sets Coefficient / 10^AScale; AScale 0..LandrixGaebDecimalMaxScale and
      a coefficient of at most 18 digits, otherwise ELandrixGaebError.
      DE: Setzt Koeffizient / 10^AScale; AScale 0..LandrixGaebDecimalMaxScale
      und ein Koeffizient mit hoechstens 18 Ziffern, sonst ELandrixGaebError. }
    procedure SetValue(ACoefficient: Int64; AScale: Integer);
    function Coefficient: Int64;
    function Scale: Integer;
    { Parses an xs:decimal lexical form ("12.500", "-3", "+.5"; no
      exponent, surrounding XML white space ignored). False (and the value
      unchanged) if the text is no decimal or does not fit (more than 18
      significant digits or scale above the maximum).
      DE: Liest eine xs:decimal-Form ("12.500", "-3", "+.5"; kein Exponent,
      umgebender XML-Leerraum wird ignoriert). False (Wert unveraendert),
      wenn der Text keine Dezimalzahl ist oder nicht passt (mehr als 18
      gueltige Ziffern oder Skala ueber dem Maximum). }
    function TrySetText(const AText: TLandrixXmlUtf8): Boolean;
    { The value with exactly Scale fraction digits and '.' as separator,
      e.g. '12.500', '-0.05', '7'; '' when not set.
      DE: Der Wert mit genau Skala Nachkommastellen und '.' als Trenner,
      z. B. '12.500', '-0.05', '7'; '' wenn nicht gesetzt. }
    function Text: TLandrixXmlUtf8;
    { The value with exactly AScale fraction digits (zeros added or trailing
      zeros removed). False if the value is not set or has significant
      digits beyond AScale (never rounds).
      DE: Der Wert mit genau AScale Nachkommastellen (Nullen ergaenzt oder
      nachlaufende Nullen entfernt). False, wenn der Wert nicht gesetzt ist
      oder werttragende Stellen jenseits von AScale hat (rundet nie). }
    function TryTextWithScale(AScale: Integer; out AText: TLandrixXmlUtf8): Boolean;
    { The value as arbitrary-precision decimal for exact calculations;
      ELandrixGaebError when not set.
      DE: Der Wert als beliebig genaue Dezimalzahl fuer exakte Rechnungen;
      ELandrixGaebError, wenn nicht gesetzt. }
    function AsXmlDecimal: TLandrixXmlDecimal;
    { True if both are unset, or both are set with the same value
      (12.5 = 12.500).
      DE: True, wenn beide nicht gesetzt sind oder beide denselben Wert
      haben (12.5 = 12.500). }
    function Equals(const AOther: TLandrixGaebDecimal): Boolean;
  end;

  { Unbounded decimal value (tgDecimal): the validated lexical form as read
    (surrounding white space removed). Zeroed memory means "not set".
    Old-style object without VMT; padded so that its size is never 8 bytes.
    DE: Unbegrenzter Dezimalwert (tgDecimal): die gepruefte Form wie gelesen
    (umgebender Leerraum entfernt). Nullspeicher bedeutet "nicht gesetzt".
    Object ohne VMT; aufgefuellt, damit es nie 8 Byte gross ist. }
  TLandrixGaebDecimalText = object
  private
    FText: TLandrixXmlUtf8;
    FHasValue: Boolean;
    FReserved: Int64;
  public
    procedure Clear;
    function HasValue: Boolean;
    { Accepts any xs:decimal lexical form. False (value unchanged)
      otherwise.
      DE: Nimmt jede xs:decimal-Form an. Sonst False (Wert unveraendert). }
    function TrySetText(const AText: TLandrixXmlUtf8): Boolean;
    { Sets the value from a decimal (shortest exact form, e.g. '0.5').
      DE: Setzt den Wert aus einer Dezimalzahl (kuerzeste exakte Form,
      z. B. '0.5'). }
    procedure SetXmlDecimal(const AValue: TLandrixXmlDecimal);
    { The text as stored; '' when not set. DE: Der gespeicherte Text; ''
      wenn nicht gesetzt. }
    function Text: TLandrixXmlUtf8;
    { ELandrixGaebError when not set. DE: ELandrixGaebError, wenn nicht
      gesetzt. }
    function AsXmlDecimal: TLandrixXmlDecimal;
    { Value comparison as in TLandrixGaebDecimal.Equals.
      DE: Wertvergleich wie bei TLandrixGaebDecimal.Equals. }
    function Equals(const AOther: TLandrixGaebDecimalText): Boolean;
  end;

{ Rounds commercially: to Precision fraction digits, ties away from zero
  (2.345 -> 2.35, -2.345 -> -2.35). LandrixXml has no such mode; this
  wraps its half-ceiling rounding on the absolute value.
  DE: Rundet kaufmaennisch auf Precision Nachkommastellen, bei genau halb
  weg von null (2.345 -> 2.35, -2.345 -> -2.35). LandrixXml kennt diesen
  Modus nicht; die Funktion nutzt dessen Halb-aufwaerts-Rundung auf dem
  Betrag. }
function LandrixGaebRoundHalfAwayFromZero(const A: TLandrixXmlDecimal;
  Precision: Integer): TLandrixXmlDecimal;

type
  { How strictly the writer reacts to problems.
    DE: Wie streng der Schreiber auf Probleme reagiert. }
  TLandrixGaebXmlWriteMode = (
    { Any warning or error aborts; nothing is written. DE: Jede Warnung
      oder jeder Fehler bricht ab; nichts wird geschrieben. }
    gwmStrict,
    { Errors abort, warnings are allowed. DE: Fehler brechen ab, Warnungen
      sind erlaubt. }
    gwmNormal,
    { Nothing aborts: what the target does not allow is left out and
      reported as warning (loss report). DE: Nichts bricht ab: Was das
      Ziel nicht erlaubt, wird weggelassen und als Warnung gemeldet
      (Verlustbericht). }
    gwmBestEffort
  );

  { Options of a write. A record without methods (Delphi 6); always start
    from LandrixGaebXmlDefaultWriteOptions and change single fields: later
    releases may add fields, which then get their default there.
    DE: Optionen eines Schreibvorgangs. Record ohne Methoden (Delphi 6);
    immer mit LandrixGaebXmlDefaultWriteOptions beginnen und einzelne
    Felder aendern: spaetere Versionen koennen Felder hinzufuegen, die
    dort ihren Standardwert bekommen. }
  TLandrixGaebXmlWriteOptions = record
    { See TLandrixGaebXmlWriteMode. DE: Siehe TLandrixGaebXmlWriteMode. }
    Mode: TLandrixGaebXmlWriteMode;
    { Write decimals with the scale they have instead of the fraction
      digits of the target type. DE: Dezimale mit ihrer Skala statt mit
      den Nachkommastellen des Zieltyps schreiben. }
    PreserveScale: Boolean;
    { UTF-8 byte order mark at the start. DE: UTF-8-BOM am Anfang. }
    WriteBom: Boolean;
    { Indent outside of text blocks. DE: Einruecken ausserhalb von
      Textbloecken. }
    Indent: Boolean;
    { CR LF instead of LF as line break. DE: CR LF statt LF als
      Zeilenumbruch. }
    CrLf: Boolean;
    { Check the output against the content models of the target
      (LandrixGaebXmlCheck, stage 2); its findings are errors (in mode
      gwmBestEffort reported without abort).
      DE: Die Ausgabe gegen die Inhaltsmodelle des Ziels pruefen
      (LandrixGaebXmlCheck, Stufe 2); ihre Befunde sind Fehler (im Modus
      gwmBestEffort gemeldet ohne Abbruch). }
    Check: Boolean;
    { Fraction digits of unit prices (UP, UPComp1 to UPComp6), 2 or 3:
      UPFracDig of the request (PrjInfo of the X83), which the bid itself
      does not carry. A price with more significant digits is a loss
      (GAEB-WRT-002), never rounded. -1 (default): the digits of the
      schema type. Ignored with PreserveScale.
      DE: Nachkommastellen der Einheitspreise (UP, UPComp1 bis UPComp6),
      2 oder 3: UPFracDig der Anfrage (PrjInfo des X83), das das Angebot
      selbst nicht traegt. Ein Preis mit mehr werttragenden Stellen ist
      ein Verlust (GAEB-WRT-002), nie gerundet. -1 (Standard): die
      Stellen des Schematyps. Bei PreserveScale ohne Wirkung. }
    UPFracDig: Integer;
  end;

{ Default options: gwmNormal, decimals normalized to the target type,
  output checked, UPFracDig -1, no BOM, indented, CR LF.
  DE: Standardoptionen: gwmNormal, Dezimale auf den Zieltyp normalisiert,
  Ausgabe geprueft, UPFracDig -1, keine BOM, eingerueckt, CR LF. }
function LandrixGaebXmlDefaultWriteOptions: TLandrixGaebXmlWriteOptions;

{ Builds a target. DE: Baut eine Zielangabe. }
function LandrixGaebTarget(AVersion: TLandrixGaebVersion;
  AEdition: TLandrixGaebEdition; APhase: TLandrixGaebPhase): TLandrixGaebTarget;

{ DP text of a phase ('83', '50.1', '84Z'); '' for gpUnknown.
  DE: DP-Text einer Phase ('83', '50.1', '84Z'); '' fuer gpUnknown. }
function LandrixGaebPhaseToDP(APhase: TLandrixGaebPhase): TLandrixXmlUtf8;
{ Phase of a DP text (surrounding white space ignored, case-sensitive as in
  the schemas); gpUnknown if unknown.
  DE: Phase zu einem DP-Text (umgebender Leerraum wird ignoriert,
  Gross-/Kleinschreibung wie in den Schemas); gpUnknown, wenn unbekannt. }
function LandrixGaebPhaseFromDP(const ADP: TLandrixXmlUtf8): TLandrixGaebPhase;

{ Version text ('3.3'); '' for gvUnknown. DE: Versionstext ('3.3'); '' fuer
  gvUnknown. }
function LandrixGaebVersionToText(AVersion: TLandrixGaebVersion): TLandrixXmlUtf8;
function LandrixGaebVersionFromText(const AText: TLandrixXmlUtf8): TLandrixGaebVersion;

{ VersDate text of an edition ('2021-05'); '' for geUnknown.
  DE: VersDate-Text einer Ausgabe ('2021-05'); '' fuer geUnknown. }
function LandrixGaebEditionToText(AEdition: TLandrixGaebEdition): TLandrixXmlUtf8;
function LandrixGaebEditionFromText(const AText: TLandrixXmlUtf8): TLandrixGaebEdition;

{ Namespace URI of a target: from 3.2 on one per version and phase
  ('http://www.gaeb.de/GAEB_DA_XML/DA83/3.3'; 50.1/50.2 share DA50),
  3.0 and 3.1 the common '.../200407' (3.1 trade phases 93-97: '.../200706').
  '' when version or phase is unknown.
  DE: Namespace-URI eines Ziels: ab 3.2 je Version und Phase einer
  ('http://www.gaeb.de/GAEB_DA_XML/DA83/3.3'; 50.1/50.2 teilen DA50),
  3.0 und 3.1 der gemeinsame '.../200407' (3.1 Handel 93-97: '.../200706').
  '' bei unbekannter Version oder Phase. }
function LandrixGaebTargetNamespace(const ATarget: TLandrixGaebTarget): TLandrixXmlUtf8;
{ VersDate to write for a target. '' when the edition is unknown and for
  3.0 and 3.1/2007-11, whose schemas leave VersDate free (official samples
  carry 2004-08 and 2007-06).
  DE: Zu schreibendes VersDate eines Ziels. '' bei unbekannter Ausgabe und
  fuer 3.0 und 3.1/2007-11, deren Schemas VersDate offen lassen (offizielle
  Musterdateien tragen 2004-08 und 2007-06). }
function LandrixGaebTargetVersDate(const ATarget: TLandrixGaebTarget): TLandrixXmlUtf8;
{ True if the library supports the target. Reading: 3.2 (2013-10; the
  time-contract phases 83Z, 84Z, 86ZE, 86ZR only 2014-03) and 3.3 (2019-11,
  2021-05; X31 also 2023-01), only phases that exist in that edition.
  Writing: the same without 3.3/2019-11 and without beta phases (61, 84P,
  98, 99); 3.3/2023-01 X31 is writable. 3.0 (2004-07) and 3.1 (2007-11,
  2009-12) only for reading, phases 81 to 86 (3.1/2009-12 also 87), into
  the same model; DP 88, the trade phases of 3.1 and the 3.4 beta are not
  supported.
  DE: True, wenn die Bibliothek das Ziel unterstuetzt. Lesen: 3.2
  (2013-10; Zeitvertragsphasen auch 2014-03) und 3.3 (2019-11, 2021-05; X31
  auch 2023-01), nur Phasen, die es in der Ausgabe gibt. Schreiben: dasselbe
  ohne 3.3/2019-11 und ohne Beta-Phasen (61, 84P, 98, 99); 3.3/2023-01 X31
  ist schreibbar. 3.0 (2004-07) und 3.1 (2007-11, 2009-12) nur zum Lesen,
  Phasen 81 bis 86 (3.1/2009-12 auch 87), in dasselbe Modell; DP 88, die
  Handelsphasen von 3.1 und die Beta 3.4 werden nicht unterstuetzt. }
function LandrixGaebTargetIsSupported(const ATarget: TLandrixGaebTarget;
  AForWriting: Boolean): Boolean;

implementation

const
  PhaseDP: array[TLandrixGaebPhase] of string = ('', '31', '50.1',
    '50.2', '51.1', '51.2', '52', '61', '80', '81', '82', '83', '83Z',
    '84', '84P', '84Z', '85', '86', '86ZE', '86ZR', '87', '88', '89', '89B',
    '93', '94', '96', '97', '98', '99');

  { Suffix of the 3.2+ namespace (DA50 for 50.1 and 50.2). }
  PhaseNamespace: array[TLandrixGaebPhase] of string = ('', '31',
    '50', '50', '51', '51', '52', '61', '80', '81', '82', '83', '83Z',
    '84', '84P', '84Z', '85', '86', '86ZE', '86ZR', '87', '', '89', '89B',
    '93', '94', '96', '97', '98', '99');

  VersionText: array[TLandrixGaebVersion] of string = ('', '3.0', '3.1',
    '3.2', '3.3', '3.4');

  EditionText: array[TLandrixGaebEdition] of string = ('', '2004-07',
    '2007-11', '2009-12', '2013-10', '2014-03', '2019-11', '2021-05',
    '2023-01', '2026-03');

  NamespaceBase = 'http://www.gaeb.de/GAEB_DA_XML/';

  { Phases with a schema in 3.2 (2013-10 set; the time-contract phases
    only in the 2014-03 set). }
  Phases32: TLandrixGaebPhases = [gp31, gp52, gp80, gp81, gp82, gp83, gp83Z,
    gp84, gp84Z, gp85, gp86, gp86ZE, gp86ZR, gp87, gp89, gp93, gp94, gp96,
    gp97];
  { Time-contract phases (3.2: own schema edition 2014-03). }
  PhasesTimeContract: TLandrixGaebPhases = [gp83Z, gp84Z, gp86ZE, gp86ZR];
  { Phases with a schema in 3.3/2019-11. }
  Phases33_2019: TLandrixGaebPhases = [gp31, gp50_1, gp50_2,
    gp51_1, gp51_2, gp52, gp80, gp81, gp82, gp83, gp83Z, gp84, gp84Z, gp85,
    gp86, gp86ZE, gp86ZR, gp87, gp89, gp93, gp94, gp96, gp97];
  { 3.3/2021-05 adds 89B and the beta phases 61, 84P, 98, 99. }
  PhasesBeta33: TLandrixGaebPhases = [gp61, gp84P, gp98, gp99];
  { Phases read from 3.0 and 3.1/2007-11 (88 is not supported); 3.1/2009-12
    also has 87. }
  PhasesLegacy: TLandrixGaebPhases = [gp81, gp82, gp83, gp84, gp85, gp86];

function Trimmed(const S: TLandrixXmlUtf8): string;
var
  First, Last: Integer;
begin
  First := 1;
  Last := Length(S);
  while (First <= Last) and (S[First] in [' ', #9, #10, #13]) do
    Inc(First);
  while (Last >= First) and (S[Last] in [' ', #9, #10, #13]) do
    Dec(Last);
  Result := LandrixXmlUtf8ToString(Copy(S, First, Last - First + 1));
end;

{ TLandrixGaebDecimal }

procedure TLandrixGaebDecimal.Clear;
begin
  FCoefficient := 0;
  FScale := 0;
  FHasValue := False;
end;

function TLandrixGaebDecimal.HasValue: Boolean;
begin
  Result := FHasValue;
end;

procedure TLandrixGaebDecimal.SetValue(ACoefficient: Int64; AScale: Integer);
begin
  if (AScale < 0) or (AScale > LandrixGaebDecimalMaxScale) then
    raise ELandrixGaebError.Create('decimal scale out of range: ' + IntToStr(AScale));
  if (ACoefficient > LandrixGaebDecimalMaxCoefficient) or
    (ACoefficient < -LandrixGaebDecimalMaxCoefficient) then
    raise ELandrixGaebError.Create('decimal coefficient has more than 18 digits');
  FCoefficient := ACoefficient;
  FScale := AScale;
  FHasValue := True;
end;

function TLandrixGaebDecimal.Coefficient: Int64;
begin
  Result := FCoefficient;
end;

function TLandrixGaebDecimal.Scale: Integer;
begin
  Result := FScale;
end;

function TLandrixGaebDecimal.TrySetText(const AText: TLandrixXmlUtf8): Boolean;
var
  S: string;
  I, Digits, FractionDigits, Digit: Integer;
  Negative, SeenPoint, SeenDigit: Boolean;
  Value: Int64;
begin
  Result := False;
  S := Trimmed(AText);
  I := 1;
  Negative := False;
  if (I <= Length(S)) and ((S[I] = '+') or (S[I] = '-')) then
  begin
    Negative := S[I] = '-';
    Inc(I);
  end;
  Value := 0;
  Digits := 0;
  FractionDigits := 0;
  SeenPoint := False;
  SeenDigit := False;
  while I <= Length(S) do
  begin
    if S[I] = '.' then
    begin
      if SeenPoint then
        Exit;
      SeenPoint := True;
    end
    else if (S[I] >= '0') and (S[I] <= '9') then
    begin
      SeenDigit := True;
      { leading zeros do not count; at most 18 significant digits always
        fit into Int64 }
      if (Value <> 0) or (S[I] <> '0') then
        Inc(Digits);
      if Digits > 18 then
        Exit;
      Digit := Ord(S[I]) - Ord('0');
      Value := Value * 10 + Digit;
      if SeenPoint then
      begin
        Inc(FractionDigits);
        if FractionDigits > LandrixGaebDecimalMaxScale then
          Exit;
      end;
    end
    else
      Exit;
    Inc(I);
  end;
  if not SeenDigit then
    Exit;
  if Negative then
    Value := -Value;
  FCoefficient := Value;
  FScale := FractionDigits;
  FHasValue := True;
  Result := True;
end;

function TLandrixGaebDecimal.Text: TLandrixXmlUtf8;
var
  Digits: string;
  Negative: Boolean;
  Magnitude: Int64;
begin
  Result := '';
  if not FHasValue then
    Exit;
  Negative := FCoefficient < 0;
  { the magnitude as text, digit by digit: IntToStr(Int64) of Delphi 7
    goes through the FPU on some systems. Low(Int64) cannot occur: at most
    18 digits. }
  if Negative then
    Magnitude := -FCoefficient
  else
    Magnitude := FCoefficient;
  Digits := '';
  repeat
    Digits := Chr(Ord('0') + Integer(Magnitude mod 10)) + Digits;
    Magnitude := Magnitude div 10;
  until Magnitude = 0;
  while Length(Digits) <= FScale do
    Digits := '0' + Digits;
  if FScale > 0 then
    Digits := Copy(Digits, 1, Length(Digits) - FScale) + '.' +
      Copy(Digits, Length(Digits) - FScale + 1, FScale);
  if Negative then
    Digits := '-' + Digits;
  Result := LandrixXmlStringToUtf8(Digits);
end;

function TLandrixGaebDecimal.TryTextWithScale(AScale: Integer;
  out AText: TLandrixXmlUtf8): Boolean;
var
  S, IntPart, Frac: string;
  Dot, I: Integer;
begin
  Result := False;
  AText := '';
  if not FHasValue or (AScale < 0) then
    Exit;
  S := LandrixXmlUtf8ToString(Text);
  Dot := Pos('.', S);
  if Dot > 0 then
  begin
    IntPart := Copy(S, 1, Dot - 1);
    Frac := Copy(S, Dot + 1, MaxInt);
  end
  else
  begin
    IntPart := S;
    Frac := '';
  end;
  if Length(Frac) > AScale then
  begin
    for I := AScale + 1 to Length(Frac) do
      if Frac[I] <> '0' then
        Exit;
    Frac := Copy(Frac, 1, AScale);
  end;
  while Length(Frac) < AScale do
    Frac := Frac + '0';
  if Frac <> '' then
    S := IntPart + '.' + Frac
  else
    S := IntPart;
  if S = '-0' then
    S := '0';
  AText := LandrixXmlStringToUtf8(S);
  Result := True;
end;

function TLandrixGaebDecimal.AsXmlDecimal: TLandrixXmlDecimal;
begin
  if not FHasValue then
    raise ELandrixGaebError.Create('decimal value not set');
  Result := LandrixXmlDecimalMultiplyPow10(
    LandrixXmlDecimalFromInt64(FCoefficient), -FScale);
end;

function TLandrixGaebDecimal.Equals(const AOther: TLandrixGaebDecimal): Boolean;
begin
  if FHasValue <> AOther.FHasValue then
    Result := False
  else if not FHasValue then
    Result := True
  else
    Result := LandrixXmlDecimalCompare(AsXmlDecimal, AOther.AsXmlDecimal) = 0;
end;

{ TLandrixGaebDecimalText }

procedure TLandrixGaebDecimalText.Clear;
begin
  FText := '';
  FHasValue := False;
  FReserved := 0;
end;

function TLandrixGaebDecimalText.HasValue: Boolean;
begin
  Result := FHasValue;
end;

function TLandrixGaebDecimalText.TrySetText(const AText: TLandrixXmlUtf8): Boolean;
var
  D: TLandrixXmlDecimal;
begin
  Result := LandrixXmlTryParseDecimal(AText, D);
  if Result then
  begin
    FText := LandrixXmlStringToUtf8(Trimmed(AText));
    FHasValue := True;
  end;
end;

procedure TLandrixGaebDecimalText.SetXmlDecimal(const AValue: TLandrixXmlDecimal);
begin
  FText := LandrixXmlFormatDecimal(AValue);
  FHasValue := True;
end;

function TLandrixGaebDecimalText.Text: TLandrixXmlUtf8;
begin
  if FHasValue then
    Result := FText
  else
    Result := '';
end;

function TLandrixGaebDecimalText.AsXmlDecimal: TLandrixXmlDecimal;
begin
  if not FHasValue then
    raise ELandrixGaebError.Create('decimal value not set');
  Result := LandrixXmlParseDecimal(FText);
end;

function TLandrixGaebDecimalText.Equals(const AOther: TLandrixGaebDecimalText): Boolean;
begin
  if FHasValue <> AOther.FHasValue then
    Result := False
  else if not FHasValue then
    Result := True
  else
    Result := LandrixXmlDecimalCompare(AsXmlDecimal, AOther.AsXmlDecimal) = 0;
end;

{ functions }

function LandrixGaebRoundHalfAwayFromZero(const A: TLandrixXmlDecimal;
  Precision: Integer): TLandrixXmlDecimal;
begin
  if LandrixXmlDecimalSign(A) < 0 then
    Result := LandrixXmlDecimalNegate(LandrixXmlDecimalRound(
      LandrixXmlDecimalAbs(A), Precision, xdrHalfCeiling))
  else
    Result := LandrixXmlDecimalRound(A, Precision, xdrHalfCeiling);
end;

function LandrixGaebTarget(AVersion: TLandrixGaebVersion;
  AEdition: TLandrixGaebEdition; APhase: TLandrixGaebPhase): TLandrixGaebTarget;
begin
  Result.Version := AVersion;
  Result.Edition := AEdition;
  Result.Phase := APhase;
end;

function LandrixGaebPhaseToDP(APhase: TLandrixGaebPhase): TLandrixXmlUtf8;
begin
  Result := LandrixXmlStringToUtf8(PhaseDP[APhase]);
end;

function LandrixGaebPhaseFromDP(const ADP: TLandrixXmlUtf8): TLandrixGaebPhase;
var
  S: string;
  P: TLandrixGaebPhase;
begin
  Result := gpUnknown;
  S := Trimmed(ADP);
  if S = '' then
    Exit;
  for P := Succ(gpUnknown) to High(TLandrixGaebPhase) do
    if PhaseDP[P] = S then
    begin
      Result := P;
      Exit;
    end;
end;

function LandrixGaebVersionToText(AVersion: TLandrixGaebVersion): TLandrixXmlUtf8;
begin
  Result := LandrixXmlStringToUtf8(VersionText[AVersion]);
end;

function LandrixGaebVersionFromText(const AText: TLandrixXmlUtf8): TLandrixGaebVersion;
var
  S: string;
  V: TLandrixGaebVersion;
begin
  Result := gvUnknown;
  S := Trimmed(AText);
  if S = '' then
    Exit;
  for V := Succ(gvUnknown) to High(TLandrixGaebVersion) do
    if VersionText[V] = S then
    begin
      Result := V;
      Exit;
    end;
end;

function LandrixGaebEditionToText(AEdition: TLandrixGaebEdition): TLandrixXmlUtf8;
begin
  Result := LandrixXmlStringToUtf8(EditionText[AEdition]);
end;

function LandrixGaebEditionFromText(const AText: TLandrixXmlUtf8): TLandrixGaebEdition;
var
  S: string;
  E: TLandrixGaebEdition;
begin
  Result := geUnknown;
  S := Trimmed(AText);
  if S = '' then
    Exit;
  for E := Succ(geUnknown) to High(TLandrixGaebEdition) do
    if EditionText[E] = S then
    begin
      Result := E;
      Exit;
    end;
end;

function LandrixGaebTargetNamespace(const ATarget: TLandrixGaebTarget): TLandrixXmlUtf8;
begin
  Result := '';
  if ATarget.Phase = gpUnknown then
    Exit;
  case ATarget.Version of
    gv30:
      Result := NamespaceBase + '200407';
    gv31:
      if ATarget.Phase in [gp93, gp94, gp96, gp97] then
        Result := NamespaceBase + '200706'
      else
        Result := NamespaceBase + '200407';
    gv32, gv33, gv34:
      if PhaseNamespace[ATarget.Phase] <> '' then
        Result := LandrixXmlStringToUtf8(NamespaceBase + 'DA' +
          PhaseNamespace[ATarget.Phase] + '/' + VersionText[ATarget.Version]);
  else
    Result := '';
  end;
end;

function LandrixGaebTargetVersDate(const ATarget: TLandrixGaebTarget): TLandrixXmlUtf8;
begin
  if ATarget.Edition in [ge2004_07, ge2007_11] then
    Result := ''
  else
    Result := LandrixXmlStringToUtf8(EditionText[ATarget.Edition]);
end;

function LandrixGaebTargetIsSupported(const ATarget: TLandrixGaebTarget;
  AForWriting: Boolean): Boolean;
begin
  case ATarget.Version of
    gv30:
      Result := (not AForWriting) and (ATarget.Edition = ge2004_07) and (ATarget.Phase in PhasesLegacy);
    gv31:
      case ATarget.Edition of
        ge2007_11:
          Result := (not AForWriting) and (ATarget.Phase in PhasesLegacy);
        ge2009_12:
          Result := (not AForWriting) and (ATarget.Phase in PhasesLegacy + [gp87]);
      else
        Result := False;
      end;
    gv32:
      case ATarget.Edition of
        ge2013_10:
          Result := ATarget.Phase in Phases32 - PhasesTimeContract;
        ge2014_03:
          Result := ATarget.Phase in PhasesTimeContract;
      else
        Result := False;
      end;
    gv33:
      case ATarget.Edition of
        ge2019_11:
          Result := (not AForWriting) and (ATarget.Phase in Phases33_2019);
        ge2021_05:
          if AForWriting then
            Result := ATarget.Phase in Phases33_2019 + [gp89B]
          else
            Result := ATarget.Phase in Phases33_2019 + [gp89B] + PhasesBeta33;
        ge2023_01:
          Result := ATarget.Phase = gp31;
      else
        Result := False;
      end;
  else
    Result := False;
  end;
end;

function LandrixGaebXmlDefaultWriteOptions: TLandrixGaebXmlWriteOptions;
begin
  Result.Mode := gwmNormal;
  Result.PreserveScale := False;
  Result.WriteBom := False;
  Result.Indent := True;
  Result.CrLf := True;
  Result.Check := True;
  Result.UPFracDig := -1;
end;

end.
