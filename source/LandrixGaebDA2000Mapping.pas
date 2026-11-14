{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Mapping of a parsed GAEB DA 2000 file (LandrixGaebDA2000Parser) into the
  syntax model of GAEB DA XML 3.3 (2021-05). Hand-written, element by
  element; what has no counterpart, or is not mapped yet, stays marked
  as unused in the parser tree and is reported once per file and key.

  Mapped (exchange phases 81 to 86, object Vergabe):
  - GAEBInfo (program, date, time), PrjInfo (name, label, description,
    currency);
  - VergabeInfo -> AwardInfo (currency, dates, contract, warranty);
  - AG -> OWN, AN -> CTR, each with Adresse -> Address;
  - LV: LVInfo -> BoQInfo (name, label, date, text kind, unit price
    components, time label, totals), LVGlied -> BoQBkdn (derived from the
    ordinal numbers when LVGlied is missing), LVBereich -> BoQCtgy,
    Position -> Item, Hinweis -> Remark, AusfBeschr -> PerfDescr (AusfNr
    -> PerfNo, AusfBez -> PerfLbl, each Beschreibung -> Description);
  - references of an item: BezugBeschr B/W -> RefDescr Ref/Rep, BezugOZ
    -> RefRNo and BezugAusfNr -> RefPerfNo (IDRef of the item or
    execution description with that number in the file);
  - KatZuord (LVInfo, LVBereich, Position, Adresse) -> CtlgAssign
    (CtlgCode = KatSchl) with one BoQInfo/Ctlg per catalogue: CtlgID and
    CtlgType = the name of the catalogue file (ExtDat) or, in the form
    with the keys KatNam and KatBez that GAEB DA 2000 does not define but
    programs write (owner decision 14.11.2026), KatNam; CtlgName = its
    description (ExtDatBeschr, KatBez) or the name;
  - Beschreibung -> Description: Kurztext -> OutlineText, Langtext ->
    DetailTxt, as plain paragraphs with text complements
    (LandrixGaebDA2000Text).
  Numbers accept a comma or a point; dates TT.MM.JJJJ become YYYY-MM-DD,
  times HH:MM become HH:MM:SS. IDs are generated (LGB, LGC, LGI, LGR, LGP
  plus a number); they do not exist in GAEB DA 2000.

  Diagnostics (rule identifiers):
    GAEB-BR-D2000-008 error        a number that is no decimal number
    GAEB-BR-D2000-009 warning      a date or time in another form
    GAEB-BR-D2000-010 warning      a key GAEB DA 2000 does not define, read
                                   as the defined one (BezText as Bez)
    GAEB-BR-D2000-015 error        ordinal numbers that do not fit the
                                   breakdown (once per file with a count)
    GAEB-BR-D2000-016 error        categories and items on one level
    GAEB-D2000-MAP-001 information an element or object not mapped (once
                                   per key with the number of uses)
    GAEB-D2000-MAP-002 information formatting of texts dropped
    GAEB-D2000-MAP-003 warning      text complement marks that do not pair
    GAEB-D2000-MAP-004 warning      a value outside the values of GAEB DA
                                   2000, not mapped; catalogues with a name
                                   or description too long for GAEB DA
                                   XML, kept
    GAEB-D2000-MAP-005 information  BoQBkdn derived from the ordinal
                                   numbers
    GAEB-D2000-MAP-006 warning      control characters removed from values
                                   (XML 1.0 cannot carry them)
    GAEB-D2000-MAP-007 information  Num of breakdown levels without any
                                   value set (No for an index, Yes else)
    GAEB-D2000-MAP-008 information  keys and marks GAEB DA 2000 does not
                                   define, read as other programs write
                                   them (once per kind with a count):
                                   LVGlied/Format (A -> Num No, N -> Num
                                   Yes), LVGlied/_GAEBXML_Alignment (left,
                                   right -> Alignment), complements marked
                                   in plain text (LandrixGaebDA2000Text)
    GAEB-D2000-MAP-009 warning      execution descriptions without
                                   AusfNr, AusfBez or Beschreibung, which
                                   PerfDescr requires, catalogue
                                   assignments without catalogue or key
                                   and catalogues of a file without LV
                                   (left missing; once per file and kind
                                   with a count)
    GAEB-D2000-MAP-010 warning      BezugOZ or BezugAusfNr naming no item
                                   or execution description of the file
                                   (left out; once per file with a
                                   count)
  Messages name keys, never values.

  DE: Abbildung einer gelesenen GAEB-DA-2000-Datei in das Syntaxmodell
  von GAEB DA XML 3.3 (2021-05), von Hand, Element fuer Element; was kein
  Gegenstueck hat oder noch nicht abgebildet ist, bleibt im Parserbaum
  unbenutzt und wird je Datei und Schluessel einmal gemeldet. Meldungen
  nennen Schluessel, nie Werte. }

{ API: internal. May change in any release, also after 1.0; use the
  stable units instead (see README).
  DE: API: intern. Kann sich in jeder Version aendern, auch nach 1.0;
  stattdessen die stabilen Units verwenden (siehe README). }

unit LandrixGaebDA2000Mapping;

{$I LandrixGaeb.inc}

interface

uses
  SysUtils,
  Classes,
  Contnrs,
  LandrixGaebTypes,
  LandrixGaebDiagnostics,
  LandrixGaebDetect,
  LandrixGaebXmlModel,
  LandrixGaebDA2000Parser;

{ Maps ADocument into a new GAEB DA XML 3.3 document. ATarget is
  3.3/2021-05 with the phase of the file. Raises ELandrixGaebError when
  the file holds no object Vergabe or a phase other than 81 to 86.
  ADiagnostics and AInvalidTotals may be nil; AInvalidTotals (not owning)
  receives the TLandrixGaebXmlTotals whose Summe the source holds in an unusable form
  (left unset and reported), so that a caller filling missing totals can
  pass over them.
  DE: Bildet ADocument in ein neues Dokument GAEB DA XML 3.3 ab. ATarget
  ist 3.3/2021-05 mit der Phase der Datei. Loest ELandrixGaebError aus,
  wenn die Datei kein Objekt Vergabe oder eine andere Phase als 81 bis 86
  enthaelt. ADiagnostics und AInvalidTotals duerfen nil sein;
  AInvalidTotals erhaelt die TLandrixGaebXmlTotals, deren Summe die Quelle
  in unbrauchbarer Form enthaelt (nicht gesetzt und gemeldet), damit ein
  Aufrufer, der fehlende Summen fuellt, sie uebergehen kann. }
function LandrixGaebDA2000Map(ADocument: TLandrixGaebDA2000Document;
  ADiagnostics: TLandrixGaebDiagnostics; AInvalidTotals: TObjectList;
  out ATarget: TLandrixGaebTarget): TLandrixGaebXmlGAEB;

{ Reads a GAEB DA 2000 file held in Buffer: detection, parser and mapping.
  AMaxSize <= 0 means LandrixGaebDefaultMaxSize; ACharset as in
  LandrixGaebDA2000Parse. ADetection describes the input, ATarget the
  returned document. Raises ELandrixGaebError for input larger than
  AMaxSize, input that is no GAEB DA 2000 and the errors of the parser and
  the mapping. The caller owns the result.
  DE: Liest eine GAEB-DA-2000-Datei aus Buffer: Erkennung, Parser und
  Abbildung. AMaxSize <= 0 bedeutet LandrixGaebDefaultMaxSize; ACharset wie
  bei LandrixGaebDA2000Parse. ADetection beschreibt die Eingabe, ATarget
  das gelieferte Dokument. Loest ELandrixGaebError aus fuer Eingaben ueber
  AMaxSize, Eingaben, die kein GAEB DA 2000 sind, und die Fehler von Parser
  und Abbildung. Das Ergebnis gehoert dem Aufrufer. }
function LandrixGaebDA2000ReadMapped(Buffer: Pointer; Size: Integer; AMaxSize: Int64;
  ACharset: TLandrixGaebCharset; ADiagnostics: TLandrixGaebDiagnostics; AInvalidTotals: TObjectList;
  out ADetection: TLandrixGaebDetection; out ATarget: TLandrixGaebTarget): TLandrixGaebXmlGAEB;

{ The same for a stream from its current position to its end (it must
  know its Size); the size limit is checked before anything is read.
  DE: Dasselbe fuer einen Stream ab der aktuellen Position bis zum Ende
  (er muss seine Groesse kennen); die Groessengrenze wird geprueft, bevor
  etwas gelesen wird. }
function LandrixGaebDA2000ReadMappedStream(AStream: TStream; AMaxSize: Int64;
  ACharset: TLandrixGaebCharset; ADiagnostics: TLandrixGaebDiagnostics; AInvalidTotals: TObjectList;
  out ADetection: TLandrixGaebDetection; out ATarget: TLandrixGaebTarget): TLandrixGaebXmlGAEB;

implementation

uses
  LandrixXmlBase,
  LandrixGaebDA2000Text;

const
  RuleNumber = 'GAEB-BR-D2000-008';
  RuleDate = 'GAEB-BR-D2000-009';
  RuleUndefined = 'GAEB-BR-D2000-010';
  RuleBreakdown = 'GAEB-BR-D2000-015';
  RuleLevels = 'GAEB-BR-D2000-016';
  RuleNotMapped = 'GAEB-D2000-MAP-001';
  RuleFormat = 'GAEB-D2000-MAP-002';
  RuleMarks = 'GAEB-D2000-MAP-003';
  RuleValue = 'GAEB-D2000-MAP-004';
  RuleBkdn = 'GAEB-D2000-MAP-005';
  RuleControl = 'GAEB-D2000-MAP-006';
  RuleUnusedLevel = 'GAEB-D2000-MAP-007';
  RuleOther = 'GAEB-D2000-MAP-008';
  RuleIncomplete = 'GAEB-D2000-MAP-009';
  RuleReference = 'GAEB-D2000-MAP-010';

type
  { One level of the breakdown: its kind and length. }
  TLevel = record
    Kind: string;
    Length: Integer;
  end;

  TMapper = class(TObject)
  private
    FDiags: TLandrixGaebDiagnostics;
    FNextId: Integer;
    FLevels: array of TLevel;
    { texts }
    FFormatTexts: Integer;
    { keys and marks GAEB DA 2000 does not define, read (RuleOther) }
    FPlainMarks, FFormatKeys, FAlignKeys: Integer;
    { execution descriptions without a required part (RuleIncomplete) }
    FIncompletePerf: Integer;
    { catalogues of KatZuord: name, description; count of the form with
      KatNam/KatBez and of assignments without catalogue or key }
    FCtlgNames, FCtlgLabels: array of TLandrixGaebString;
    FCtlgCount: Integer;
    FKatNamForm, FIncompleteKat: Integer;
    { catalogues with a name or description too long for GAEB DA XML, and
      catalogues of a file without LV (no BoQInfo to define them) }
    FLongCtlg, FCtlgWithoutLV: Integer;
    { numbers of items and execution descriptions with their IDs, and the
      references to resolve after the mapping }
    FItemNos, FItemIds, FPerfNos, FPerfIds: array of TLandrixGaebString;
    FItemCount, FPerfCount: Integer;
    FRefs: array of TLandrixGaebXmlRefItem;
    FRefKeys: array of TLandrixGaebString;
    FRefIsPerf: array of Boolean;
    FRefCount, FUnresolved: Integer;
    FLosses: TLandrixGaebDA2000Losses;
    FMarkProblems: Integer;
    FControlChars: Integer;
    { ordinal numbers that do not fit the breakdown }
    FBadNumbers: Integer;
    { set while FillNum looks at the numbers: nothing is counted twice }
    FQuiet: Boolean;
    { totals whose Summe is unusable (may be nil) }
    FInvalidTotals: TObjectList;
    procedure Report(ANode: TLandrixGaebDA2000Node; const ARuleId: string;
      ASeverity: TLandrixGaebSeverity; const AMessage: string);
    function NewId(const APrefix: string): TLandrixGaebString;
    { access to the parser tree; every access marks what it took }
    function Child(ANode: TLandrixGaebDA2000Node; const AKey: string): TLandrixGaebDA2000Node;
    function Str(ANode: TLandrixGaebDA2000Node; const AKey: string): TLandrixGaebString;
    function Text(ANode: TLandrixGaebDA2000Node; const AKey: string): TLandrixGaebString;
    function Yes(ANode: TLandrixGaebDA2000Node; const AKey: string): TLandrixGaebString;
    function Enum(ANode: TLandrixGaebDA2000Node; const AKey: string;
      const ACodes, AValues: string): TLandrixGaebString;
    procedure Num(ANode: TLandrixGaebDA2000Node; const AKey: string; var ADecimal: TLandrixGaebDecimal);
    function DateOf(ANode: TLandrixGaebDA2000Node; const AKey: string): TLandrixGaebString;
    function TimeOf(ANode: TLandrixGaebDA2000Node; const AKey: string): TLandrixGaebString;
    { parts }
    procedure MapAddress(ANode: TLandrixGaebDA2000Node; AAddress: TLandrixGaebXmlAddress);
    procedure MapMLText(const AValue: TLandrixGaebString; AText: TLandrixGaebXmlMLText);
    procedure MapPlain(const AValue: TLandrixGaebString; AText: TLandrixGaebXmlFText);
    procedure MapComplement(APart: TLandrixGaebDA2000TextPart; AComplement: TLandrixGaebXmlTextComplement);
    procedure Account(AText: TLandrixGaebDA2000Text);
    function ReadClean(const AValue: TLandrixGaebString): TLandrixGaebDA2000Text;
    function HasText(const AValue: TLandrixGaebString): Boolean;
    procedure MapLongText(const AValue: TLandrixGaebString; ADetail: TLandrixGaebXmlBoQText);
    procedure MapShortText(const AValue: TLandrixGaebString; AOutline: TLandrixGaebXmlOutlTxt);
    procedure MapTexts(B: TLandrixGaebDA2000Node; ADescription: TLandrixGaebXmlDescription;
      APerf: TLandrixGaebXmlPerfDescription);
    procedure MapDescription(ANode: TLandrixGaebDA2000Node; ADescription: TLandrixGaebXmlDescription);
    procedure MapTotals(ANode: TLandrixGaebDA2000Node; ATotals: TLandrixGaebXmlTotals);
    procedure MapBreakdown(ALV: TLandrixGaebDA2000Node; AInfo: TLandrixGaebXmlBoQInfo);
    procedure FillNum(ALV: TLandrixGaebDA2000Node; AInfo: TLandrixGaebXmlBoQInfo);
    function Part(const AOZ: TLandrixGaebString; ALevel: Integer; out AIndex: TLandrixGaebString): TLandrixGaebString;
    procedure MapItem(ANode: TLandrixGaebDA2000Node; AItem: TLandrixGaebXmlItem);
    procedure MapRemark(ANode: TLandrixGaebDA2000Node; ARemark: TLandrixGaebXmlRemark);
    procedure MapPerfDescr(ANode: TLandrixGaebDA2000Node; APerf: TLandrixGaebXmlPerfDescr);
    procedure MapCatalogs(ANode: TLandrixGaebDA2000Node; AAssign: TLandrixGaebXmlCtlgAssignList);
    procedure MapCatalog(K: TLandrixGaebDA2000Node; AAssign: TLandrixGaebXmlCtlgAssignList);
    procedure AddCatalogs(AInfo: TLandrixGaebXmlBoQInfo);
    procedure AddRef(ARef: TLandrixGaebXmlRefItem; const AKey: TLandrixGaebString; AIsPerf: Boolean);
    procedure ResolveRefs;
    procedure MapBody(ANode: TLandrixGaebDA2000Node; ADepth: Integer; ABody: TLandrixGaebXmlBoQBody);
    procedure ReportUnused(ARoot: TLandrixGaebDA2000Node);
  public
    function Map(ADocument: TLandrixGaebDA2000Document; ADiagnostics: TLandrixGaebDiagnostics;
      AInvalidTotals: TObjectList; out ATarget: TLandrixGaebTarget): TLandrixGaebXmlGAEB;
  end;

function W(const S: string): TLandrixGaebString;
begin
  Result := LandrixXmlUtf8ToWide(LandrixXmlStringToUtf8(S));
end;

function TrimW(const S: TLandrixGaebString): TLandrixGaebString;
var
  A, B: Integer;
begin
  A := 1;
  B := Length(S);
  while (A <= B) and ((S[A] = ' ') or (S[A] = #9) or (S[A] = #10) or (S[A] = #13)) do
    Inc(A);
  while (B >= A) and ((S[B] = ' ') or (S[B] = #9) or (S[B] = #10) or (S[B] = #13)) do
    Dec(B);
  Result := Copy(S, A, B - A + 1);
end;

{ An ASCII value as string, '' if it holds other characters. }
function AsciiOf(const S: TLandrixGaebString): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(S) do
  begin
    if Ord(S[I]) >= 128 then
    begin
      Result := '';
      Exit;
    end;
    Result := Result + Char(Ord(S[I]));
  end;
end;

procedure TMapper.Report(ANode: TLandrixGaebDA2000Node; const ARuleId: string;
  ASeverity: TLandrixGaebSeverity; const AMessage: string);
var
  Line: Integer;
begin
  if FDiags = nil then
    Exit;
  Line := 0;
  if ANode <> nil then
    Line := ANode.Line;
  FDiags.AddAt(ARuleId, ASeverity, '', Line, 0, -1, AMessage);
end;

function TMapper.NewId(const APrefix: string): TLandrixGaebString;
begin
  Inc(FNextId);
  Result := W(APrefix + IntToStr(FNextId));
end;

function TMapper.Child(ANode: TLandrixGaebDA2000Node; const AKey: string): TLandrixGaebDA2000Node;
var
  I: Integer;
begin
  Result := nil;
  if ANode = nil then
    Exit;
  for I := 0 to ANode.Count - 1 do
    if (not ANode[I].Used) and (CompareText(ANode[I].Key, AKey) = 0) then
    begin
      Result := ANode[I];
      Result.Used := True;
      Exit;
    end;
end;

{ True if S[I] cannot be written in XML 1.0: a control character other
  than tab, line feed and carriage return, U+FFFE, U+FFFF, or half of a
  surrogate pair without its other half. }
function BadXmlChar(const S: TLandrixGaebString; I: Integer): Boolean;
var
  C: Word;
begin
  C := Ord(S[I]);
  if (C >= $D800) and (C <= $DBFF) then
    Result := (I >= Length(S)) or (Ord(S[I + 1]) < $DC00) or (Ord(S[I + 1]) > $DFFF)
  else if (C >= $DC00) and (C <= $DFFF) then
    Result := (I <= 1) or (Ord(S[I - 1]) < $D800) or (Ord(S[I - 1]) > $DBFF)
  else
    Result := ((C < 32) and (C <> 9) and (C <> 10) and (C <> 13)) or (C = $FFFE) or (C = $FFFF);
end;

{ S without the characters XML 1.0 cannot carry (BadXmlChar); ACount is
  increased by their number. }
function XmlSafe(const S: TLandrixGaebString; var ACount: Integer): TLandrixGaebString;
var
  I, N: Integer;
begin
  N := 0;
  for I := 1 to Length(S) do
    if BadXmlChar(S, I) then
      Inc(N);
  if N = 0 then
  begin
    Result := S;
    Exit;
  end;
  Inc(ACount, N);
  Result := '';
  SetLength(Result, Length(S) - N);
  N := 0;
  for I := 1 to Length(S) do
    if not BadXmlChar(S, I) then
    begin
      Inc(N);
      Result[N] := S[I];
    end;
end;

function TMapper.Text(ANode: TLandrixGaebDA2000Node; const AKey: string): TLandrixGaebString;
var
  N: TLandrixGaebDA2000Node;
begin
  N := Child(ANode, AKey);
  if (N <> nil) and not N.IsObject then
    Result := XmlSafe(N.Value, FControlChars)
  else
    Result := '';
end;

function TMapper.Str(ANode: TLandrixGaebDA2000Node; const AKey: string): TLandrixGaebString;
begin
  Result := TrimW(Text(ANode, AKey));
end;

{ Field I (0-based) of a list separated by |, '' if there is none. }
function FieldOf(const AList: string; AIndex: Integer): string;
var
  I, Start, N: Integer;
begin
  Result := '';
  N := 0;
  Start := 1;
  for I := 1 to Length(AList) + 1 do
    if (I > Length(AList)) or (AList[I] = '|') then
    begin
      if N = AIndex then
      begin
        Result := Copy(AList, Start, I - Start);
        Exit;
      end;
      Inc(N);
      Start := I + 1;
    end;
end;

{ The value of AKey mapped from the codes ACodes to the values AValues
  (lists separated by |); a code not in the list is reported. }
function TMapper.Enum(ANode: TLandrixGaebDA2000Node; const AKey: string;
  const ACodes, AValues: string): TLandrixGaebString;
var
  N: TLandrixGaebDA2000Node;
  V, Code: string;
  I: Integer;
begin
  Result := '';
  N := Child(ANode, AKey);
  if (N = nil) or N.IsObject then
    Exit;
  V := AsciiOf(TrimW(N.Value));
  I := 0;
  repeat
    Code := FieldOf(ACodes, I);
    if Code = '' then
      Break;
    if CompareText(V, Code) = 0 then
    begin
      Result := W(FieldOf(AValues, I));
      Exit;
    end;
    Inc(I);
  until False;
  Report(N, RuleValue, gsWarning, AKey + ': value not defined in GAEB DA 2000, not mapped');
end;

function TMapper.Yes(ANode: TLandrixGaebDA2000Node; const AKey: string): TLandrixGaebString;
begin
  Result := Enum(ANode, AKey, 'J', 'Yes');
end;

procedure TMapper.Num(ANode: TLandrixGaebDA2000Node; const AKey: string; var ADecimal: TLandrixGaebDecimal);
var
  N: TLandrixGaebDA2000Node;
  S: string;
  I, Seps, Digits: Integer;
  Ok: Boolean;
begin
  N := Child(ANode, AKey);
  if (N = nil) or N.IsObject then
    Exit;
  S := AsciiOf(TrimW(N.Value));
  { comma or point, at most one, digits, a leading minus; no grouping }
  Seps := 0;
  Digits := 0;
  Ok := S <> '';
  for I := 1 to Length(S) do
    if (S[I] >= '0') and (S[I] <= '9') then
      Inc(Digits)
    else if (S[I] = ',') or (S[I] = '.') then
    begin
      Inc(Seps);
      S[I] := '.';
    end
    else if not ((S[I] = '-') and (I = 1)) then
      Ok := False;
  if Ok and (Seps <= 1) and (Digits > 0) then
  begin
    if S[1] = '.' then
      S := '0' + S
    else if (Length(S) >= 2) and (S[1] = '-') and (S[2] = '.') then
      S := '-0' + Copy(S, 2, MaxInt);
    if S[Length(S)] = '.' then
      S := S + '0';
    if ADecimal.TrySetText(LandrixXmlStringToUtf8(S)) then
      Exit;
  end;
  Report(N, RuleNumber, gsError, AKey + ': no decimal number, not mapped');
end;

function TwoDigits(const S: string): Boolean;
begin
  Result := (Length(S) = 2) and (S[1] >= '0') and (S[1] <= '9') and (S[2] >= '0') and (S[2] <= '9');
end;

function TMapper.DateOf(ANode: TLandrixGaebDA2000Node; const AKey: string): TLandrixGaebString;
var
  N: TLandrixGaebDA2000Node;
  S, D, M, Y: string;
  P1, P2: Integer;
begin
  Result := '';
  N := Child(ANode, AKey);
  if (N = nil) or N.IsObject then
    Exit;
  S := AsciiOf(TrimW(N.Value));
  P1 := Pos('.', S);
  if P1 > 0 then
  begin
    D := Copy(S, 1, P1 - 1);
    S := Copy(S, P1 + 1, MaxInt);
    P2 := Pos('.', S);
    M := Copy(S, 1, P2 - 1);
    Y := Copy(S, P2 + 1, MaxInt);
    if Length(D) = 1 then
      D := '0' + D;
    if Length(M) = 1 then
      M := '0' + M;
    if (P2 > 0) and TwoDigits(D) and TwoDigits(M) and (Length(Y) = 4) and
      TwoDigits(Copy(Y, 1, 2)) and TwoDigits(Copy(Y, 3, 2)) then
    begin
      Result := W(Y + '-' + M + '-' + D);
      Exit;
    end;
  end
  else if (Length(S) = 8) and TwoDigits(Copy(S, 1, 2)) and TwoDigits(Copy(S, 3, 2)) and
    TwoDigits(Copy(S, 5, 2)) and TwoDigits(Copy(S, 7, 2)) then
  begin
    { TTMMJJJJ without points occurs in practice }
    Report(N, RuleDate, gsWarning, AKey + ': date without points, read as TTMMJJJJ');
    Result := W(Copy(S, 5, 4) + '-' + Copy(S, 3, 2) + '-' + Copy(S, 1, 2));
    Exit;
  end;
  Report(N, RuleDate, gsWarning, AKey + ': not a date TT.MM.JJJJ, not mapped');
end;

function TMapper.TimeOf(ANode: TLandrixGaebDA2000Node; const AKey: string): TLandrixGaebString;
var
  N: TLandrixGaebDA2000Node;
  S: string;
begin
  Result := '';
  N := Child(ANode, AKey);
  if (N = nil) or N.IsObject then
    Exit;
  S := AsciiOf(TrimW(N.Value));
  if (Length(S) = 5) and TwoDigits(Copy(S, 1, 2)) and (S[3] = ':') and TwoDigits(Copy(S, 4, 2)) then
    Result := W(S + ':00')
  else if (Length(S) = 8) and TwoDigits(Copy(S, 1, 2)) and (S[3] = ':') and
    TwoDigits(Copy(S, 4, 2)) and (S[6] = ':') and TwoDigits(Copy(S, 7, 2)) then
  begin
    Report(N, RuleDate, gsWarning, AKey + ': time with seconds');
    Result := W(S);
  end
  else
    Report(N, RuleDate, gsWarning, AKey + ': not a time HH:MM, not mapped');
end;

{ ---- addresses and texts ---- }

procedure TMapper.MapAddress(ANode: TLandrixGaebDA2000Node; AAddress: TLandrixGaebXmlAddress);
begin
  AAddress.Name1 := Str(ANode, 'Name1');
  AAddress.Name2 := Str(ANode, 'Name2');
  AAddress.Name3 := Str(ANode, 'Name3');
  AAddress.Name4 := Str(ANode, 'Name4');
  AAddress.Street := Str(ANode, 'Strasse');
  AAddress.PCode := Str(ANode, 'PLZ');
  AAddress.City := Str(ANode, 'Ort');
  AAddress.Country := Str(ANode, 'LandBez');
  AAddress.ILN := Str(ANode, 'ILN');
  AAddress.Contact := Str(ANode, 'AnsprPartner');
  AAddress.Phone := Str(ANode, 'Telefon');
  AAddress.Fax := Str(ANode, 'Fax');
  AAddress.Email := Str(ANode, 'Email');
  AAddress.VATID := Str(ANode, 'UStIdent');
  MapCatalogs(ANode, AAddress.CtlgAssign);
end;

{ A value read as text (LandrixGaebDA2000Text), its losses counted and
  every part cleaned of characters XML cannot carry (RTF can produce them
  through escapes). }
function TMapper.ReadClean(const AValue: TLandrixGaebString): TLandrixGaebDA2000Text;
var
  I, J: Integer;
  P: TLandrixGaebDA2000TextPart;
begin
  Result := LandrixGaebDA2000ReadText(AValue);
  Account(Result);
  for I := 0 to Result.Count - 1 do
    for J := 0 to Result[I].Count - 1 do
    begin
      P := Result[I][J];
      P.Text := XmlSafe(P.Text, FControlChars);
      P.Caption := XmlSafe(P.Caption, FControlChars);
      P.Body := XmlSafe(P.Body, FControlChars);
      P.Tail := XmlSafe(P.Tail, FControlChars);
    end;
end;

procedure TMapper.Account(AText: TLandrixGaebDA2000Text);
begin
  if AText.Losses <> [] then
    Inc(FFormatTexts);
  FLosses := FLosses + AText.Losses;
  Inc(FMarkProblems, AText.MarkProblems);
  Inc(FPlainMarks, AText.PlainMarks);
end;

{ Text of a paragraph as lines (a #10 inside is a line break). }
procedure AddLines(const AText: TLandrixGaebString; P: TLandrixGaebXmlPMLText);
var
  I, Start: Integer;
begin
  Start := 1;
  for I := 1 to Length(AText) + 1 do
    if (I > Length(AText)) or (AText[I] = #10) then
    begin
      if I > Start then
        P.AddSpan.Value := Copy(AText, Start, I - Start);
      if I <= Length(AText) then
        P.AddBr('');
      Start := I + 1;
    end;
end;

procedure TMapper.MapMLText(const AValue: TLandrixGaebString; AText: TLandrixGaebXmlMLText);
var
  T: TLandrixGaebDA2000Text;
  I: Integer;
  P: TLandrixGaebXmlPMLText;
begin
  T := ReadClean(AValue);
  try
    for I := 0 to T.Count - 1 do
    begin
      P := AText.AddP;
      P.Present := True;
      AddLines(TrimW(T[I].Text), P);
    end;
  finally
    T.Free;
  end;
end;

procedure TMapper.MapPlain(const AValue: TLandrixGaebString; AText: TLandrixGaebXmlFText);
var
  T: TLandrixGaebDA2000Text;
  I, Start, J: Integer;
  P: TLandrixGaebXmlP;
  S: TLandrixGaebString;
begin
  T := ReadClean(AValue);
  try
    for I := 0 to T.Count - 1 do
    begin
      P := AText.AddP;
      P.Present := True;
      S := T[I].Text;
      Start := 1;
      for J := 1 to Length(S) + 1 do
        if (J > Length(S)) or (S[J] = #10) then
        begin
          if J > Start then
            P.AddSpan.Value := Copy(S, Start, J - Start);
          if J <= Length(S) then
            P.AddBr('');
          Start := J + 1;
        end;
    end;
  finally
    T.Free;
  end;
end;

procedure TMapper.MapComplement(APart: TLandrixGaebDA2000TextPart; AComplement: TLandrixGaebXmlTextComplement);
begin
  AComplement.Present := True;
  if APart.Bidder then
    AComplement.Kind := 'Bidder'
  else
    AComplement.Kind := 'Owner';
  { the digits as written, as the GAEB Toolbox writes MarkLbl }
  if APart.Mark <> '' then
    AComplement.MarkLbl := APart.Mark
  else
    AComplement.MarkLbl := W(IntToStr(APart.Number));
  if APart.Empty then
    AComplement.Empty := 'Yes';
  if APart.Caption <> '' then
    AddLines(APart.Caption, AComplement.ComplCaption.AddP);
  { the body is required; an empty complement has an empty one }
  if APart.Body <> '' then
    AddLines(APart.Body, AComplement.ComplBody.AddP)
  else
    AComplement.ComplBody.Present := True;
  if APart.Tail <> '' then
    AddLines(APart.Tail, AComplement.ComplTail.AddP);
end;

{ True if the value yields at least one paragraph (an empty RTF does not). }
function TMapper.HasText(const AValue: TLandrixGaebString): Boolean;
var
  T: TLandrixGaebDA2000Text;
begin
  Result := False;
  if TrimW(AValue) = '' then
    Exit;
  T := LandrixGaebDA2000ReadText(AValue);
  try
    { a complement is content even when its field is an empty placeholder }
    Result := (T.Count > 0) and ((TrimW(T.PlainText) <> '') or (T.ComplementCount > 0));
    { a text without content (a picture only) still reports what it lost }
    if not Result then
      Account(T);
  finally
    T.Free;
  end;
end;

procedure TMapper.MapLongText(const AValue: TLandrixGaebString; ADetail: TLandrixGaebXmlBoQText);
var
  T: TLandrixGaebDA2000Text;
  F: TLandrixGaebXmlFTextTC;
  P: TLandrixGaebXmlPTC;
  I, J, K, Start: Integer;
  S: TLandrixGaebString;
begin
  T := ReadClean(AValue);
  try
    if T.Count = 0 then
      Exit;
    F := ADetail.AddText;
    for I := 0 to T.Count - 1 do
    begin
      P := F.AddP;
      P.Present := True;
      for J := 0 to T[I].Count - 1 do
        if T[I][J].Kind = tpkComplement then
          MapComplement(T[I][J], P.AddTextComplement)
        else
        begin
          S := T[I][J].Text;
          Start := 1;
          for K := 1 to Length(S) + 1 do
            if (K > Length(S)) or (S[K] = #10) then
            begin
              if K > Start then
                P.AddSpan.Value := Copy(S, Start, K - Start);
              if K <= Length(S) then
                P.AddBr('');
              Start := K + 1;
            end;
        end;
    end;
  finally
    T.Free;
  end;
end;

procedure TMapper.MapShortText(const AValue: TLandrixGaebString; AOutline: TLandrixGaebXmlOutlTxt);
var
  T: TLandrixGaebDA2000Text;
  M: TLandrixGaebXmlMLText;
  I, J: Integer;
  Line: TLandrixGaebString;
begin
  T := ReadClean(AValue);
  try
    { text and complements follow each other in OutlTxt }
    M := nil;
    for I := 0 to T.Count - 1 do
    begin
      Line := '';
      for J := 0 to T[I].Count - 1 do
        if T[I][J].Kind = tpkComplement then
        begin
          if Line <> '' then
          begin
            if M = nil then
              M := AOutline.AddTextOutlTxt;
            AddLines(Line, M.AddP);
            Line := '';
          end;
          MapComplement(T[I][J], AOutline.AddTextComplement);
          M := nil;
        end
        else
          Line := Line + T[I][J].Text;
      if Line <> '' then
      begin
        if M = nil then
          M := AOutline.AddTextOutlTxt;
        AddLines(Line, M.AddP);
      end
      else if T[I].Count = 0 then
      begin
        { an empty paragraph stays one }
        if M = nil then
          M := AOutline.AddTextOutlTxt;
        M.AddP.Present := True;
      end;
    end;
  finally
    T.Free;
  end;
end;

{ Beschreibung B into ADescription or, if that is nil, into APerf (the
  same content model). }
procedure TMapper.MapTexts(B: TLandrixGaebDA2000Node; ADescription: TLandrixGaebXmlDescription;
  APerf: TLandrixGaebXmlPerfDescription);
var
  Long, Short: TLandrixGaebString;

  function Complete: TLandrixGaebXmlCompleteText;
  begin
    if ADescription <> nil then
      Result := ADescription.CompleteText
    else
      Result := APerf.CompleteText;
  end;

  function Outline: TLandrixGaebXmlOutlineText;
  begin
    if ADescription <> nil then
      Result := ADescription.OutlineText
    else
      Result := APerf.OutlineText;
  end;

begin
  Long := Text(B, 'Langtext');
  Short := Text(B, 'Kurztext');
  if not HasText(Long) then
    Long := '';
  if not HasText(Short) then
    Short := '';
  if Long <> '' then
  begin
    MapLongText(Long, Complete.DetailTxt);
    Complete.ComplTSA := Yes(B, 'LangtextTA');
    Complete.ComplTSB := Yes(B, 'LangtextTB');
    if Short <> '' then
    begin
      MapShortText(Short, Complete.OutlineText.OutlTxt);
      Complete.OutlineText.OutlTSA := Yes(B, 'KurztextTA');
    end;
  end
  else if Short <> '' then
  begin
    { without a long text the short text stands alone (CompleteText needs
      DetailTxt) }
    MapShortText(Short, Outline.OutlTxt);
    Outline.OutlTSA := Yes(B, 'KurztextTA');
  end;
end;

procedure TMapper.MapDescription(ANode: TLandrixGaebDA2000Node; ADescription: TLandrixGaebXmlDescription);
var
  B: TLandrixGaebDA2000Node;
begin
  B := Child(ANode, 'Beschreibung');
  if B <> nil then
    MapTexts(B, ADescription, nil);
end;

procedure TMapper.MapTotals(ANode: TLandrixGaebDA2000Node; ATotals: TLandrixGaebXmlTotals);
var
  N: TLandrixGaebDA2000Node;
begin
  N := ANode.Find('Summe');
  Num(ANode, 'Summe', ATotals.Total);
  { an unusable Summe (no number, or an object instead of a value) is not
    the same as a missing one: a computed value must not replace it
    silently }
  if (N <> nil) and not ATotals.Total.HasValue and (FInvalidTotals <> nil) then
    FInvalidTotals.Add(ATotals);
  Num(ANode, 'NachlassProz', ATotals.DiscountPcnt);
  Num(ANode, 'NachlassAbs', ATotals.DiscountAmt);
  Num(ANode, 'SummeNachNL', ATotals.TotAfterDisc);
  Num(ANode, 'SummePsch', ATotals.TotalLSUM);
  Num(ANode, 'USt', ATotals.VAT);
  Num(ANode, 'SummeBrutto', ATotals.TotalGross);
end;

{ ---- breakdown and ordinal numbers ---- }

procedure TMapper.MapBreakdown(ALV: TLandrixGaebDA2000Node; AInfo: TLandrixGaebXmlBoQInfo);
var
  Info, G: TLandrixGaebDA2000Node;
  Kind, Lbl, NumOf, AlignOf: TLandrixGaebString;
  Len: TLandrixGaebDecimal;
  K: string;
  Bkdn: TLandrixGaebXmlBoQBkdn;
  N: Integer;

  { lengths from the ordinal numbers: categories by depth, then items }
  procedure Derive(ANode: TLandrixGaebDA2000Node; ADepth, AUsed: Integer);
  var
    I, L, Dummy: Integer;
    OZ: TLandrixGaebString;
  begin
    Dummy := 0;
    for I := 0 to ANode.Count - 1 do
      if ANode[I].IsObject and ((CompareText(ANode[I].Key, 'LVBereich') = 0) or
        (CompareText(ANode[I].Key, 'Position') = 0)) then
      begin
        OZ := XmlSafe(ANode[I].ValueOf('OZ'), Dummy);
        L := Length(OZ) - AUsed;
        if L <= 0 then
          Continue;
        if CompareText(ANode[I].Key, 'LVBereich') = 0 then
        begin
          if Length(FLevels) <= ADepth then
          begin
            SetLength(FLevels, ADepth + 1);
            FLevels[ADepth].Kind := 'BoQLevel';
            FLevels[ADepth].Length := L;
          end;
          Derive(ANode[I], ADepth + 1, AUsed + FLevels[ADepth].Length);
        end
        else if Length(FLevels) = ADepth then
        begin
          SetLength(FLevels, ADepth + 1);
          FLevels[ADepth].Kind := 'Item';
          FLevels[ADepth].Length := L;
        end;
      end;
  end;

begin
  FLevels := nil;
  Info := Child(ALV, 'LVInfo');
  N := 0;
  repeat
    G := Child(Info, 'LVGlied');
    if G = nil then
      Break;
    Kind := Enum(G, 'Typ', 'Los|LVStufe|Position|Index', 'Lot|BoQLevel|Item|Index');
    Lbl := Str(G, 'Bez');
    { not defined by GAEB DA 2000, written by the GAEB Toolbox (owner
      decision 14.11.2026): Format A (alphanumeric) or N (numeric) and
      _GAEBXML_Alignment }
    NumOf := '';
    if G.Find('Format') <> nil then
    begin
      Inc(FFormatKeys);
      NumOf := Enum(G, 'Format', 'A|N', 'No|Yes');
    end;
    AlignOf := '';
    if G.Find('_GAEBXML_Alignment') <> nil then
    begin
      Inc(FAlignKeys);
      AlignOf := Enum(G, '_GAEBXML_Alignment', 'left|right', 'left|right');
    end;
    Len.Clear;
    Num(G, 'Laenge', Len);
    K := AsciiOf(Kind);
    SetLength(FLevels, N + 1);
    FLevels[N].Kind := K;
    FLevels[N].Length := 0;
    if Len.HasValue and (Len.Scale = 0) and (Len.Coefficient >= 0) and (Len.Coefficient < 100) then
      FLevels[N].Length := Integer(Len.Coefficient);
    Inc(N);
    Bkdn := AInfo.BoQBkdn.Add;
    Bkdn.Present := True;
    Bkdn.TypeElement := Kind;
    Bkdn.LblBoQBkdn := Lbl;
    Bkdn.Num := NumOf;
    Bkdn.Alignment := AlignOf;
    if FLevels[N - 1].Length > 0 then
      Bkdn.LengthElement := W(IntToStr(FLevels[N - 1].Length));
  until False;
  if N > 0 then
    Exit;
  Derive(ALV, 0, 0);
  if Length(FLevels) = 0 then
    Exit;
  Report(Info, RuleBkdn, gsInformation, 'LVGlied missing: BoQBkdn derived from the ordinal numbers');
  for N := 0 to Integer(High(FLevels)) do
  begin
    Bkdn := AInfo.BoQBkdn.Add;
    Bkdn.Present := True;
    Bkdn.TypeElement := W(FLevels[N].Kind);
    Bkdn.LengthElement := W(IntToStr(FLevels[N].Length));
  end;
end;

{ The part of AOZ of the category level ALevel (0 = top), or with ALevel
  -1 the item part, trimmed; for an item, AIndex is its index part.
  Without a usable breakdown, the whole number (trimmed). }
function TMapper.Part(const AOZ: TLandrixGaebString; ALevel: Integer;
  out AIndex: TLandrixGaebString): TLandrixGaebString;
var
  I, Start, Depth: Integer;
  HasIndex: Boolean;
  Own: TLandrixGaebString;

  { the slice of the level; a number holding only this level's part
    (it occurs) is taken whole; what fits neither is counted }
  function Slice(AStart, ALength: Integer): TLandrixGaebString;
  begin
    if Length(AOZ) >= AStart + ALength - 1 then
      Result := TrimW(Copy(AOZ, AStart, ALength))
    else if (TrimW(AOZ) <> '') and (Length(TrimW(AOZ)) <= ALength) then
      { the number does not reach this level: it holds only its own part }
      Result := TrimW(AOZ)
    else
    begin
      { a number that ends inside this level fits nowhere: not taken in
        part. The raw length decides (36 item numbers of the corpus are
        left-aligned and reach the end of their level only with their
        spaces), so "1234A " under 2/4/1 is read as a full number. }
      Result := '';
      if (TrimW(AOZ) <> '') and not FQuiet then
        Inc(FBadNumbers);
    end;
  end;

begin
  AIndex := '';
  Start := 1;
  Depth := -1;
  for I := 0 to Integer(High(FLevels)) do
  begin
    if (FLevels[I].Kind = 'Lot') or (FLevels[I].Kind = 'BoQLevel') then
    begin
      Inc(Depth);
      if Depth = ALevel then
      begin
        Result := Slice(Start, FLevels[I].Length);
        Exit;
      end;
    end
    else if FLevels[I].Kind = 'Item' then
    begin
      if ALevel >= 0 then
        Break;
      HasIndex := (I < High(FLevels)) and (FLevels[I + 1].Kind = 'Index');
      Own := TrimW(AOZ);
      if (Length(AOZ) < Start + FLevels[I].Length - 1) and HasIndex and
        (Length(Own) > FLevels[I].Length) and (Length(Own) <= FLevels[I].Length + FLevels[I + 1].Length) then
      begin
        { only the item's own part and its index }
        Result := TrimW(Copy(Own, 1, FLevels[I].Length));
        AIndex := TrimW(Copy(Own, FLevels[I].Length + 1, MaxInt));
        Exit;
      end;
      Result := Slice(Start, FLevels[I].Length);
      if HasIndex and (Length(AOZ) >= Start + FLevels[I].Length) then
        AIndex := TrimW(Copy(AOZ, Start + FLevels[I].Length, MaxInt));
      Exit;
    end;
    Inc(Start, FLevels[I].Length);
  end;
  if (Length(FLevels) = 0) or (ALevel < 0) then
    Result := TrimW(AOZ)
  else
  begin
    { a category deeper than the breakdown }
    if not FQuiet then
      Inc(FBadNumbers);
    Result := '';
  end;
end;

{ Num of each level from the ordinal numbers: Yes when every part of the
  level holds digits only, No when one holds another character. A level
  without any value (mostly a declared but unused index) gets No for an
  index, Yes otherwise, reported (owner decision 14.11.2026: Num is
  required and has no meaning for a level without values). }
procedure TMapper.FillNum(ALV: TLandrixGaebDA2000Node; AInfo: TLandrixGaebXmlBoQInfo);
var
  Seen, Other: array of Boolean;
  I, Count, Unused: Integer;

  procedure Note(ALevel: Integer; const APart: TLandrixGaebString);
  var
    J: Integer;
  begin
    if (ALevel < 0) or (ALevel >= Count) or (APart = '') then
      Exit;
    Seen[ALevel] := True;
    for J := 1 to Length(APart) do
      if (APart[J] < '0') or (APart[J] > '9') then
        Other[ALevel] := True;
  end;

  { index of the breakdown row of category depth ADepth, -1 if none }
  function CategoryRow(ADepth: Integer): Integer;
  var
    J, D: Integer;
  begin
    D := 0;
    for J := 0 to Count - 1 do
      if (FLevels[J].Kind = 'Lot') or (FLevels[J].Kind = 'BoQLevel') then
      begin
        if D = ADepth then
        begin
          Result := J;
          Exit;
        end;
        Inc(D);
      end;
    Result := -1;
  end;

  function KindRow(const AKind: string): Integer;
  var
    J: Integer;
  begin
    for J := 0 to Count - 1 do
      if FLevels[J].Kind = AKind then
      begin
        Result := J;
        Exit;
      end;
    Result := -1;
  end;

  procedure Walk(ANode: TLandrixGaebDA2000Node; ADepth: Integer);
  var
    J, Dummy: Integer;
    OZ, Index: TLandrixGaebString;
  begin
    Dummy := 0;
    for J := 0 to ANode.Count - 1 do
      if ANode[J].IsObject then
      begin
        { the same cleaned value as the mapping takes }
        OZ := XmlSafe(ANode[J].ValueOf('OZ'), Dummy);
        if CompareText(ANode[J].Key, 'LVBereich') = 0 then
        begin
          Note(CategoryRow(ADepth), Part(OZ, ADepth, Index));
          Walk(ANode[J], ADepth + 1);
        end
        else if CompareText(ANode[J].Key, 'Position') = 0 then
        begin
          Note(KindRow('Item'), Part(OZ, -1, Index));
          Note(KindRow('Index'), Index);
        end;
      end;
  end;

begin
  Count := Integer(Length(FLevels));
  if (Count = 0) or (Integer(AInfo.BoQBkdn.Count) <> Count) then
    Exit;
  Seen := nil;
  Other := nil;
  SetLength(Seen, Count);
  SetLength(Other, Count);
  for I := 0 to Count - 1 do
  begin
    Seen[I] := False;
    Other[I] := False;
  end;
  FQuiet := True;
  try
    Walk(ALV, 0);
  finally
    FQuiet := False;
  end;
  Unused := 0;
  for I := 0 to Count - 1 do
    if (AInfo.BoQBkdn[I].Num = 'No') or ((AInfo.BoQBkdn[I].Num = 'Yes') and not Other[I]) then
      { declared by LVGlied/Format and not contradicted by the values }
      Continue
    else if Other[I] then
      AInfo.BoQBkdn[I].Num := 'No'
    else if Seen[I] then
      AInfo.BoQBkdn[I].Num := 'Yes'
    else
    begin
      Inc(Unused);
      if FLevels[I].Kind = 'Index' then
        AInfo.BoQBkdn[I].Num := 'No'
      else
        AInfo.BoQBkdn[I].Num := 'Yes';
    end;
  if Unused > 0 then
    Report(nil, RuleUnusedLevel, gsInformation, IntToStr(Unused) +
      ' breakdown level(s) without any value: Num set to No for an index, Yes otherwise');
end;

procedure TMapper.MapItem(ANode: TLandrixGaebDA2000Node; AItem: TLandrixGaebXmlItem);
var
  OZ, Index, QU, Ref: TLandrixGaebString;
  No: TLandrixGaebDecimal;
  N: TLandrixGaebDA2000Node;
begin
  AItem.Present := True;
  AItem.ID := NewId('LGI');
  OZ := Text(ANode, 'OZ');
  { the number as written, for BezugOZ of other items }
  if FItemCount >= Length(FItemNos) then
  begin
    SetLength(FItemNos, 2 * FItemCount + 16);
    SetLength(FItemIds, 2 * FItemCount + 16);
  end;
  FItemNos[FItemCount] := TrimW(OZ);
  FItemIds[FItemCount] := AItem.ID;
  Inc(FItemCount);
  AItem.RNoPart := Part(OZ, -1, Index);
  AItem.RNoIndex := Index;
  AItem.ALNGroupNo := Str(ANode, 'ZZGruppeNr');
  AItem.ALNSerNo := Str(ANode, 'ZZLfdNr');
  AItem.Accepted := Enum(ANode, 'Beauftragt', 'B|Z', 'AltAccept|BasReject');
  AItem.Provis := Enum(ANode, 'Bedarf', 'E|M', 'WithoutTotal|WithTotal');
  AItem.NotAppl := Yes(ANode, 'Entf');
  AItem.HourIt := Yes(ANode, 'StPos');
  AItem.KeyIt := Yes(ANode, 'SPos');
  AItem.UPBkdn := Yes(ANode, 'EPAufgl');
  AItem.MarkupIt := Yes(ANode, 'Bezuschl');
  AItem.CONo := Str(ANode, 'NachtrNr');
  AItem.COStatus := Enum(ANode, 'NachtrStatus', '1|2|3|4|5|6|7|8', 'Recog|Filed|Offered|Withdrawn|Rejected|ObjToRecj|FormAckn|Approved');
  AItem.QtyTBD := Yes(ANode, 'FrMenge');
  Num(ANode, 'Menge', AItem.Qty);
  Num(ANode, 'VaMenge', AItem.PredQty);
  Num(ANode, 'ReMenge', AItem.BillQty);
  QU := Str(ANode, 'ME');
  AItem.QU := QU;
  if CompareText(AsciiOf(QU), 'psch') = 0 then
    AItem.LumpSumItem := 'Yes';
  Num(ANode, 'EP', AItem.UP);
  Num(ANode, 'EP110', AItem.UP110);
  Num(ANode, 'EPAnteil1', AItem.UPComp1);
  Num(ANode, 'EPAnteil2', AItem.UPComp2);
  Num(ANode, 'EPAnteil3', AItem.UPComp3);
  Num(ANode, 'EPAnteil4', AItem.UPComp4);
  Num(ANode, 'EPAnteil5', AItem.UPComp5);
  Num(ANode, 'EPAnteil6', AItem.UPComp6);
  Num(ANode, 'NachlassProz', AItem.DiscountPcnt);
  Num(ANode, 'EPVon', AItem.UPFrom);
  Num(ANode, 'EPMittel', AItem.UPAvg);
  Num(ANode, 'EPBis', AItem.UPTo);
  Num(ANode, 'EPLohnVon', AItem.UPWgFrom);
  Num(ANode, 'EPLohnMittel', AItem.UPWgAvg);
  Num(ANode, 'EPLohnBis', AItem.UPWgTo);
  Num(ANode, 'GB', AItem.IT);
  AItem.PriceInfo := Enum(ANode, 'PreisInfo', '1|2|3|4', 'scope|to|approx|lump');
  Num(ANode, 'Zeit', AItem.TimeQu);
  { references (BezugOZ only with W, it excludes BezugAusfNr: not checked,
    both are kept as the file has them) }
  AItem.RefDescr := Enum(ANode, 'BezugBeschr', 'B|W', 'Ref|Rep');
  Ref := TrimW(Text(ANode, 'BezugOZ'));
  if Ref <> '' then
    AddRef(AItem.RefRNo, Ref, False);
  No.Clear;
  N := ANode.Find('BezugAusfNr');
  Num(ANode, 'BezugAusfNr', No);
  if No.HasValue and (No.Scale = 0) and (No.Coefficient >= 0) and (No.Coefficient <= 9999) then
    AddRef(AItem.RefPerfNo, W(IntToStr(Integer(No.Coefficient))), True)
  else if No.HasValue then
    Report(N, RuleValue, gsWarning, 'BezugAusfNr: no whole number from 0 to 9999, not mapped');
  MapDescription(ANode, AItem.Description);
  MapCatalogs(ANode, AItem.CtlgAssign);
end;

procedure TMapper.MapRemark(ANode: TLandrixGaebDA2000Node; ARemark: TLandrixGaebXmlRemark);
begin
  ARemark.Present := True;
  ARemark.ID := NewId('LGR');
  MapDescription(ANode, ARemark.Description);
end;

{ Execution description (AusfBeschr): AusfNr (num 4,0) -> PerfNo, AusfBez
  -> PerfLbl, every Beschreibung -> one Description. An AusfNr that is no
  whole number from 0 to 9999 is reported and left out; a missing part is
  left missing and counted (GAEB-D2000-MAP-009).
  DE: Ausfuehrungsbeschreibung (AusfBeschr): AusfNr (num 4,0) -> PerfNo,
  AusfBez -> PerfLbl, jede Beschreibung -> eine Description. Eine AusfNr,
  die keine ganze Zahl von 0 bis 9999 ist, wird gemeldet und
  weggelassen; ein fehlender Teil bleibt fehlend und wird gezaehlt
  (GAEB-D2000-MAP-009). }
procedure TMapper.MapPerfDescr(ANode: TLandrixGaebDA2000Node; APerf: TLandrixGaebXmlPerfDescr);
var
  No: TLandrixGaebDecimal;
  B: TLandrixGaebDA2000Node;
  D: TLandrixGaebXmlPerfDescription;
begin
  APerf.Present := True;
  APerf.ID := NewId('LGP');
  No.Clear;
  B := ANode.Find('AusfNr');
  Num(ANode, 'AusfNr', No);
  if No.HasValue and (No.Scale = 0) and (No.Coefficient >= 0) and (No.Coefficient <= 9999) then
  begin
    APerf.PerfNo := W(IntToStr(Integer(No.Coefficient)));
    if FPerfCount >= Length(FPerfNos) then
    begin
      SetLength(FPerfNos, 2 * FPerfCount + 16);
      SetLength(FPerfIds, 2 * FPerfCount + 16);
    end;
    FPerfNos[FPerfCount] := APerf.PerfNo;
    FPerfIds[FPerfCount] := APerf.ID;
    Inc(FPerfCount);
  end
  else if No.HasValue then
    Report(B, RuleValue, gsWarning, 'AusfNr: no whole number from 0 to 9999, not mapped');
  APerf.PerfLbl := Str(ANode, 'AusfBez');
  repeat
    B := Child(ANode, 'Beschreibung');
    if B = nil then
      Break;
    D := APerf.Description.Add;
    D.Present := True;
    MapTexts(B, nil, D);
  until False;
  { PerfNo, PerfLbl and a description are required in GAEB DA XML; what
    is missing stays missing }
  if (APerf.PerfNo = '') or (TrimW(APerf.PerfLbl) = '') or not APerf.HasDescription then
    Inc(FIncompletePerf);
end;

{ Catalogue assignments (KatZuord, an object since V1.1, a structure
  ExtDatName|ExtDatBeschr|KatSchl in V1.0) of ANode: each one CtlgAssign
  with CtlgID = the name of its catalogue and CtlgCode = KatSchl; the
  catalogue is registered for BoQInfo/Ctlg (AddCatalogs). An assignment
  without catalogue or key is counted (RuleIncomplete) and left out.
  DE: Katalogzuordnungen (KatZuord) von ANode: je eine CtlgAssign mit
  CtlgID = Name ihres Katalogs und CtlgCode = KatSchl; der Katalog wird
  fuer BoQInfo/Ctlg vermerkt. Eine Zuordnung ohne Katalog oder Schluessel
  wird gezaehlt und weggelassen. }
procedure TMapper.MapCatalogs(ANode: TLandrixGaebDA2000Node; AAssign: TLandrixGaebXmlCtlgAssignList);
var
  K: TLandrixGaebDA2000Node;
begin
  if ANode = nil then
    Exit;
  repeat
    K := Child(ANode, 'KatZuord');
    if K = nil then
      Break;
    MapCatalog(K, AAssign);
  until False;
end;

{ One KatZuord K (see MapCatalogs). }
procedure TMapper.MapCatalog(K: TLandrixGaebDA2000Node; AAssign: TLandrixGaebXmlCtlgAssignList);
var
  Parts: TLandrixGaebStringArray;
  Name, Lbl, Code, Ext: TLandrixGaebString;
  I: Integer;
  A: TLandrixGaebXmlCtlgAssign;
begin
  Parts := nil;
  Name := '';
  Lbl := '';
  Code := '';
  if not K.IsObject then
  begin
    Parts := LandrixGaebDA2000SplitStructure(XmlSafe(K.Value, FControlChars));
    if Integer(Length(Parts)) > 0 then
      Name := TrimW(Parts[0]);
    if Integer(Length(Parts)) > 1 then
      Lbl := TrimW(Parts[1]);
    if Integer(Length(Parts)) > 2 then
      Code := TrimW(Parts[2]);
  end
  else
  begin
    Ext := Str(K, 'ExtDat');
    if Ext <> '' then
    begin
      Parts := LandrixGaebDA2000SplitStructure(Ext);
      if Integer(Length(Parts)) > 0 then
        Name := TrimW(Parts[0]);
      if Integer(Length(Parts)) > 1 then
        Lbl := TrimW(Parts[1]);
    end;
    if (K.Find('KatNam') <> nil) or (K.Find('KatBez') <> nil) then
    begin
      { not defined by GAEB DA 2000, written by programs }
      Inc(FKatNamForm);
      if Name = '' then
      begin
        Name := Str(K, 'KatNam');
        Lbl := Str(K, 'KatBez');
      end;
    end;
    Code := Str(K, 'KatSchl');
  end;
  if (Name = '') or (Code = '') then
  begin
    Inc(FIncompleteKat);
    Exit;
  end;
  I := 0;
  while (I < FCtlgCount) and (FCtlgNames[I] <> Name) do
    Inc(I);
  if I = FCtlgCount then
  begin
    SetLength(FCtlgNames, FCtlgCount + 1);
    SetLength(FCtlgLabels, FCtlgCount + 1);
    FCtlgNames[I] := Name;
    FCtlgLabels[I] := Lbl;
    Inc(FCtlgCount);
  end
  else if (FCtlgLabels[I] = '') and (Lbl <> '') then
    FCtlgLabels[I] := Lbl;
  A := AAssign.Add;
  A.Present := True;
  A.CtlgID := Name;
  A.CtlgCode := Code;
end;

{ One BoQInfo/Ctlg per catalogue of the assignments: CtlgID and CtlgType
  the name, CtlgName the description or the name.
  DE: Je Katalog der Zuordnungen ein BoQInfo/Ctlg: CtlgID und CtlgType
  der Name, CtlgName die Bezeichnung oder der Name. }
procedure TMapper.AddCatalogs(AInfo: TLandrixGaebXmlBoQInfo);
var
  I: Integer;
  C: TLandrixGaebXmlCtlg;
begin
  for I := 0 to FCtlgCount - 1 do
  begin
    C := AInfo.Ctlg.Add;
    C.Present := True;
    C.CtlgID := FCtlgNames[I];
    C.CtlgType := FCtlgNames[I];
    if FCtlgLabels[I] <> '' then
      C.CtlgName := FCtlgLabels[I]
    else
      C.CtlgName := FCtlgNames[I];
    { CtlgID holds 100, CtlgName 80 characters: kept, counted }
    if (Length(C.CtlgID) > 100) or (Length(C.CtlgName) > 80) then
      Inc(FLongCtlg);
  end;
end;

procedure TMapper.AddRef(ARef: TLandrixGaebXmlRefItem; const AKey: TLandrixGaebString; AIsPerf: Boolean);
begin
  if FRefCount >= Length(FRefs) then
  begin
    SetLength(FRefs, 2 * FRefCount + 16);
    SetLength(FRefKeys, 2 * FRefCount + 16);
    SetLength(FRefIsPerf, 2 * FRefCount + 16);
  end;
  FRefs[FRefCount] := ARef;
  FRefKeys[FRefCount] := AKey;
  FRefIsPerf[FRefCount] := AIsPerf;
  Inc(FRefCount);
end;

{ BezugOZ and BezugAusfNr become the IDRef of the first item with that
  number (as written, without surrounding spaces) or of the execution
  description with that AusfNr; a reference to no such number is counted
  (RuleReference) and left out.
  DE: BezugOZ und BezugAusfNr werden IDRef der ersten Position mit dieser
  OZ (wie geschrieben, ohne umgebende Leerzeichen) bzw. der
  Ausfuehrungsbeschreibung mit dieser AusfNr; ein Bezug auf eine nicht
  vorhandene Nummer wird gezaehlt und weggelassen. }
procedure TMapper.ResolveRefs;
var
  I, J: Integer;
  Id: TLandrixGaebString;
begin
  for I := 0 to FRefCount - 1 do
  begin
    Id := '';
    if FRefIsPerf[I] then
    begin
      for J := 0 to FPerfCount - 1 do
        if FPerfNos[J] = FRefKeys[I] then
        begin
          Id := FPerfIds[J];
          Break;
        end;
    end
    else
      for J := 0 to FItemCount - 1 do
        if FItemNos[J] = FRefKeys[I] then
        begin
          Id := FItemIds[J];
          Break;
        end;
    if Id <> '' then
    begin
      FRefs[I].IDRef := Id;
      FRefs[I].Present := True;
    end
    else
      Inc(FUnresolved);
  end;
end;

procedure TMapper.MapBody(ANode: TLandrixGaebDA2000Node; ADepth: Integer; ABody: TLandrixGaebXmlBoQBody);
var
  I: Integer;
  N: TLandrixGaebDA2000Node;
  Ctgy: TLandrixGaebXmlBoQCtgy;
  HasCtgy, HasItem: Boolean;
  Index, Lbl: TLandrixGaebString;
begin
  ABody.Present := True;
  HasCtgy := False;
  HasItem := False;
  for I := 0 to ANode.Count - 1 do
    if ANode[I].IsObject and not ANode[I].Used then
    begin
      if CompareText(ANode[I].Key, 'LVBereich') = 0 then
        HasCtgy := True
      else if CompareText(ANode[I].Key, 'Position') = 0 then
        HasItem := True;
    end;
  if HasCtgy and HasItem then
    Report(ANode, RuleLevels, gsError, 'categories and items on one level');
  for I := 0 to ANode.Count - 1 do
  begin
    N := ANode[I];
    if (not N.IsObject) or N.Used then
      Continue;
    if CompareText(N.Key, 'LVBereich') = 0 then
    begin
      N.Used := True;
      Ctgy := ABody.AddBoQCtgy;
      Ctgy.Present := True;
      Ctgy.ID := NewId('LGC');
      Ctgy.RNoPart := Part(Text(N, 'OZ'), ADepth, Index);
      { Bez (V1.0/V1.1) or BezTx (V1.2); BezText is not defined but occurs }
      Lbl := Text(N, 'Bez');
      if TrimW(Lbl) = '' then
        Lbl := Text(N, 'BezTx');
      if TrimW(Lbl) = '' then
      begin
        Lbl := Text(N, 'BezText');
        if TrimW(Lbl) <> '' then
          Report(N, RuleUndefined, gsWarning, 'BezText is not defined in GAEB DA 2000; read as Bez');
      end;
      if TrimW(Lbl) <> '' then
        MapMLText(Lbl, Ctgy.LblTx);
      Ctgy.ALNBGroupNo := Str(N, 'ZZVGruppeNr');
      Ctgy.ALNBSerNo := Str(N, 'ZZVLfdNr');
      Ctgy.Accepted := Enum(N, 'Beauftragt', 'B|Z', 'AltAccept|BasReject');
      Ctgy.NotApplBoQ := Yes(N, 'Entf');
      MapCatalogs(N, Ctgy.CtlgAssign);
      MapBody(N, ADepth + 1, Ctgy.BoQBody);
      MapTotals(N, Ctgy.Totals);
    end
    else if CompareText(N.Key, 'Position') = 0 then
    begin
      N.Used := True;
      MapItem(N, ABody.Itemlist.AddItem);
    end
    else if CompareText(N.Key, 'Hinweis') = 0 then
    begin
      N.Used := True;
      if HasItem or not HasCtgy then
        MapRemark(N, ABody.Itemlist.AddRemark)
      else
        MapRemark(N, ABody.AddRemark);
    end
    else if CompareText(N.Key, 'AusfBeschr') = 0 then
    begin
      N.Used := True;
      if HasItem or not HasCtgy then
        MapPerfDescr(N, ABody.Itemlist.AddPerfDescr)
      else
        MapPerfDescr(N, ABody.AddPerfDescr);
    end;
  end;
  if ABody.HasItemlist then
    ABody.Itemlist.Present := True;
end;

{ ---- what was not mapped ---- }

procedure TMapper.ReportUnused(ARoot: TLandrixGaebDA2000Node);
var
  Keys: TStringList;
  Counts: array of Integer;
  Lines: array of Integer;
  I: Integer;

  procedure Walk(ANode: TLandrixGaebDA2000Node; const APath: string);
  var
    J, K: Integer;
    Key, Path: string;
  begin
    for J := 0 to ANode.Count - 1 do
    begin
      Key := ANode[J].Key;
      if (Key <> '') and (Key[1] = '_') then
        Key := '_*';
      Path := APath + '/' + Key;
      if not ANode[J].Used then
      begin
        K := Keys.IndexOf(Path);
        if K < 0 then
        begin
          K := Keys.Add(Path);
          SetLength(Counts, K + 1);
          SetLength(Lines, K + 1);
          Counts[K] := 0;
          Lines[K] := ANode[J].Line;
        end;
        Inc(Counts[K]);
      end
      else if ANode[J].IsObject then
        Walk(ANode[J], Path);
    end;
  end;

begin
  Keys := TStringList.Create;
  try
    Walk(ARoot, ARoot.Key);
    for I := 0 to Keys.Count - 1 do
      if FDiags <> nil then
        FDiags.AddAt(RuleNotMapped, gsInformation, '', Lines[I], 0, -1,
          Keys[I] + ' not mapped (' + IntToStr(Counts[I]) + ' time(s))');
  finally
    Keys.Free;
  end;
end;

{ ---- document ---- }

function TMapper.Map(ADocument: TLandrixGaebDA2000Document; ADiagnostics: TLandrixGaebDiagnostics;
  AInvalidTotals: TObjectList; out ATarget: TLandrixGaebTarget): TLandrixGaebXmlGAEB;
var
  Root, Info, Prj, V, VI, AG, AN, LV, LI, Adr: TLandrixGaebDA2000Node;
  DP: string;
  Phase: TLandrixGaebPhase;
  G: TLandrixGaebXmlGAEB;
  BoQ: TLandrixGaebXmlBoQ;
  Descr, Lbl: TLandrixGaebString;
  LossText: string;
begin
  FDiags := ADiagnostics;
  FInvalidTotals := AInvalidTotals;
  Root := ADocument.Root;
  Root.Used := True;
  V := Child(Root, 'Vergabe');
  if V = nil then
    raise ELandrixGaebError.Create('GAEB DA 2000: no object Vergabe; only the exchange phases 81 to 86 are read');
  DP := AsciiOf(Str(V, 'DP'));
  Phase := LandrixGaebPhaseFromDP(LandrixXmlStringToUtf8(DP));
  if not (Phase in [gp81, gp82, gp83, gp84, gp85, gp86]) then
  begin
    { only a phase number is named, never another value }
    if (Length(DP) = 2) and (DP[1] >= '0') and (DP[1] <= '9') and (DP[2] >= '0') and (DP[2] <= '9') then
      raise ELandrixGaebError.Create('GAEB DA 2000: exchange phase ' + DP + ' is not read (81 to 86)')
    else
      raise ELandrixGaebError.Create('GAEB DA 2000: DP is no exchange phase; only 81 to 86 are read');
  end;
  ATarget := LandrixGaebTarget(gv33, ge2021_05, Phase);
  G := TLandrixGaebXmlGAEB.Create;
  try
    Info := Child(Root, 'GAEBInfo');
    G.GAEBInfo.Present := True;
    G.GAEBInfo.Version := '3.3';
    G.GAEBInfo.VersDate := '2021-05';
    G.GAEBInfo.Date := DateOf(Info, 'Datum');
    G.GAEBInfo.Time := TimeOf(Info, 'Uhrzeit');
    G.GAEBInfo.ProgSystem := Str(Info, 'ProgSystem');
    G.GAEBInfo.ProgName := Str(Info, 'ProgName');
    { read by the parser and the detection }
    Child(Info, 'Version');
    Child(Info, 'Zeichensatz');

    Prj := Child(Root, 'PrjInfo');
    G.PrjInfo.Present := True;
    G.PrjInfo.NamePrj := Str(Prj, 'Name');
    G.PrjInfo.LblPrj := Str(Prj, 'Bez');
    Descr := Text(Prj, 'Beschreib');
    if TrimW(Descr) <> '' then
      MapPlain(Descr, G.PrjInfo.Descrip);
    G.PrjInfo.Cur := Str(Prj, 'Wae');
    G.PrjInfo.CurLbl := Str(Prj, 'WaeBez');

    G.Award.Present := True;
    G.Award.DP := W(DP);
    VI := Child(V, 'VergabeInfo');
    if VI <> nil then
    begin
      G.Award.AwardInfo.Present := True;
      G.Award.AwardInfo.Cur := Str(VI, 'Wae');
      G.Award.AwardInfo.CurLbl := Str(VI, 'WaeBez');
      G.Award.AwardInfo.BidDate := DateOf(VI, 'AngebDatum');
      G.Award.AwardInfo.OpenDate := DateOf(VI, 'ErDatum');
      G.Award.AwardInfo.OpenTime := TimeOf(VI, 'ErUhrzeit');
      G.Award.AwardInfo.EvalEnd := DateOf(VI, 'ZusEnde');
      G.Award.AwardInfo.SubmLoc := Str(VI, 'AbgabeOrt');
      G.Award.AwardInfo.CnstStart := DateOf(VI, 'AusfBeginn');
      G.Award.AwardInfo.CnstEnd := DateOf(VI, 'AusfEnde');
      G.Award.AwardInfo.ContrNo := Str(VI, 'AuftrNr');
      G.Award.AwardInfo.ContrDate := DateOf(VI, 'AuftrDatum');
      G.Award.AwardInfo.AcceptType := Str(VI, 'AbnahmeArt');
      G.Award.AwardInfo.AcceptDate := DateOf(VI, 'AbnahmeDatum');
      G.Award.AwardInfo.WarrDur := Str(VI, 'GwlDauer');
      G.Award.AwardInfo.WarrUnit := Enum(VI, 'GwlEinheit', 'Jahre|Monate', 'Years|Months');
      G.Award.AwardInfo.WarrEnd := DateOf(VI, 'GwlEnde');
      Num(VI, 'AusfProz', G.Award.AwardInfo.PerformPcnt);
      Num(VI, 'GwlProz', G.Award.AwardInfo.WarrantPcnt);
    end;

    AG := Child(V, 'AG');
    if AG <> nil then
    begin
      G.Award.OWN.Present := True;
      G.Award.OWN.DPNo := Str(AG, 'DVNr');
      G.Award.OWN.AwardNo := Str(AG, 'VergNr');
      G.Award.OWN.AcctRecNo := Str(AG, 'DebitorNr');
      G.Award.OWN.CntryType := Enum(AG, 'ArtStaat', 'EWR|anderer', 'EEA|Other');
      G.Award.OWN.CntryName := Str(AG, 'NameStaat');
      Adr := Child(AG, 'Adresse');
      if Adr <> nil then
        MapAddress(Adr, G.Award.OWN.Address);
    end;
    AN := Child(V, 'AN');
    if AN <> nil then
    begin
      G.Award.CTR.Present := True;
      G.Award.CTR.DPNo := Str(AN, 'DVNr');
      G.Award.CTR.AwardNo := Str(AN, 'VergNr');
      G.Award.CTR.AcctsPayNo := Str(AN, 'KreditorNr');
      G.Award.CTR.BidderNo := Str(AN, 'BieterNr');
      G.Award.CTR.CntryType := Enum(AN, 'ArtStaat', 'EWR|anderer', 'EEA|Other');
      G.Award.CTR.CntryName := Str(AN, 'NameStaat');
      G.Award.CTR.SectorType := Enum(AN, 'ArtBranche', 'Handwerk|Industrie|Handel|Versorgungsunternehmen|Sonstige',
        'Crafts|Industry|Dealer|UtilityComp|Other');
      G.Award.CTR.PrefBidType := Enum(AN, 'ArtBevBew', '1|2|3|4|5|6',
        'DisplPers|Refugee|Persecutee|WrkShopForDis|WrkShopForBli|Other');
      G.Award.CTR.SCType := Enum(AN, 'ArtNU', '1|2|3', 'InHouseWrk|DespInHouseCap|LackOfInHouseCap');
      Adr := Child(AN, 'Adresse');
      if Adr <> nil then
        MapAddress(Adr, G.Award.CTR.Address);
    end;

    LV := Child(V, 'LV');
    if LV <> nil then
    begin
      BoQ := G.Award.BoQ;
      BoQ.Present := True;
      BoQ.ID := NewId('LGB');
      BoQ.BoQInfo.Present := True;
      MapBreakdown(LV, BoQ.BoQInfo);
      FillNum(LV, BoQ.BoQInfo);
      LI := LV.Find('LVInfo');
      BoQ.BoQInfo.Name := Str(LI, 'Name');
      BoQ.BoQInfo.LblBoQ := Str(LI, 'Bez');
      BoQ.BoQInfo.Date := DateOf(LI, 'Datum');
      BoQ.BoQInfo.OutlCompl := Enum(LI, 'KurzLang', '1|2|3', 'AllTxt|OutTxt|DetailTxt');
      BoQ.BoQInfo.NoUPComps := Str(LI, 'AnzEPAnteile');
      { GAEB DA 2000 names a component, it does not type it: Unknown }
      Lbl := Str(LI, 'BezEPAnteil1');
      if Lbl <> '' then
      begin
        BoQ.BoQInfo.LblUPComp1.Value := Lbl;
        BoQ.BoQInfo.LblUPComp1.TypeAttr := 'Unknown';
      end;
      Lbl := Str(LI, 'BezEPAnteil2');
      if Lbl <> '' then
      begin
        BoQ.BoQInfo.LblUPComp2.Value := Lbl;
        BoQ.BoQInfo.LblUPComp2.TypeAttr := 'Unknown';
      end;
      Lbl := Str(LI, 'BezEPAnteil3');
      if Lbl <> '' then
      begin
        BoQ.BoQInfo.LblUPComp3.Value := Lbl;
        BoQ.BoQInfo.LblUPComp3.TypeAttr := 'Unknown';
      end;
      Lbl := Str(LI, 'BezEPAnteil4');
      if Lbl <> '' then
      begin
        BoQ.BoQInfo.LblUPComp4.Value := Lbl;
        BoQ.BoQInfo.LblUPComp4.TypeAttr := 'Unknown';
      end;
      Lbl := Str(LI, 'BezEPAnteil5');
      if Lbl <> '' then
      begin
        BoQ.BoQInfo.LblUPComp5.Value := Lbl;
        BoQ.BoQInfo.LblUPComp5.TypeAttr := 'Unknown';
      end;
      Lbl := Str(LI, 'BezEPAnteil6');
      if Lbl <> '' then
      begin
        BoQ.BoQInfo.LblUPComp6.Value := Lbl;
        BoQ.BoQInfo.LblUPComp6.TypeAttr := 'Unknown';
      end;
      BoQ.BoQInfo.LblTime := Str(LI, 'BezZeit');
      MapCatalogs(LI, BoQ.BoQInfo.CtlgAssign);
      if LI <> nil then
        MapTotals(LI, BoQ.BoQInfo.Totals);
      MapBody(LV, 0, BoQ.BoQBody);
      AddCatalogs(BoQ.BoQInfo);
    end
    else
      FCtlgWithoutLV := FCtlgCount;
    ResolveRefs;

    if FFormatTexts > 0 then
    begin
      LossText := '';
      if tlCharFormat in FLosses then
        LossText := LossText + ' emphasis';
      if tlTable in FLosses then
        LossText := LossText + ' tables';
      if tlPicture in FLosses then
        LossText := LossText + ' pictures';
      if tlObject in FLosses then
        LossText := LossText + ' objects';
      Report(nil, RuleFormat, gsInformation, 'formatting dropped in ' + IntToStr(FFormatTexts) +
        ' text(s):' + LossText);
    end;
    if FMarkProblems > 0 then
      Report(nil, RuleMarks, gsWarning, IntToStr(FMarkProblems) +
        ' text complement mark(s) that do not pair; their text is kept as text');
    if FBadNumbers > 0 then
      Report(nil, RuleBreakdown, gsError, IntToStr(FBadNumbers) +
        ' ordinal number part(s) that do not fit the breakdown (LVGlied); left out');
    if FControlChars > 0 then
      Report(nil, RuleControl, gsWarning, IntToStr(FControlChars) +
        ' control character(s) removed (not allowed in XML)');
    if FFormatKeys > 0 then
      Report(nil, RuleOther, gsInformation, 'LVGlied/Format (not defined in GAEB DA 2000) read as Num (' +
        IntToStr(FFormatKeys) + ' time(s))');
    if FAlignKeys > 0 then
      Report(nil, RuleOther, gsInformation, 'LVGlied/_GAEBXML_Alignment read as Alignment (' +
        IntToStr(FAlignKeys) + ' time(s))');
    if FIncompletePerf > 0 then
      Report(nil, RuleIncomplete, gsWarning, IntToStr(FIncompletePerf) +
        ' execution description(s) (AusfBeschr) without AusfNr, AusfBez or Beschreibung; left missing');
    if FKatNamForm > 0 then
      Report(nil, RuleOther, gsInformation, 'KatZuord with KatNam/KatBez (not defined in GAEB DA 2000) read as ' +
        'catalogue (' + IntToStr(FKatNamForm) + ' time(s))');
    if FIncompleteKat > 0 then
      Report(nil, RuleIncomplete, gsWarning, IntToStr(FIncompleteKat) +
        ' catalogue assignment(s) (KatZuord) without catalogue or KatSchl; left out');
    if FLongCtlg > 0 then
      Report(nil, RuleValue, gsWarning, IntToStr(FLongCtlg) +
        ' catalogue(s) (KatZuord) with a name over 100 or a description over 80 characters; kept');
    if FCtlgWithoutLV > 0 then
      Report(nil, RuleIncomplete, gsWarning, IntToStr(FCtlgWithoutLV) +
        ' catalogue(s) (KatZuord) in a file without LV: no BoQInfo/Ctlg defines them');
    if FUnresolved > 0 then
      Report(nil, RuleReference, gsWarning, IntToStr(FUnresolved) +
        ' reference(s) (BezugOZ, BezugAusfNr) to a number not in the file; left out');
    if FPlainMarks > 0 then
      Report(nil, RuleOther, gsInformation, IntToStr(FPlainMarks) +
        ' text complement(s) marked in plain text (not defined in GAEB DA 2000) read');
    ReportUnused(Root);
  except
    G.Free;
    raise;
  end;
  Result := G;
end;

function LandrixGaebDA2000Map(ADocument: TLandrixGaebDA2000Document;
  ADiagnostics: TLandrixGaebDiagnostics; AInvalidTotals: TObjectList;
  out ATarget: TLandrixGaebTarget): TLandrixGaebXmlGAEB;
var
  M: TMapper;
begin
  M := TMapper.Create;
  try
    Result := M.Map(ADocument, ADiagnostics, AInvalidTotals, ATarget);
  finally
    M.Free;
  end;
end;

function SizeLimit(AMaxSize: Int64): Int64;
begin
  Result := AMaxSize;
  if Result <= 0 then
    Result := LandrixGaebDefaultMaxSize;
  if Result > MaxInt then
    Result := MaxInt;
end;

procedure CheckSize(ASize, AMaxSize: Int64);
begin
  if ASize > SizeLimit(AMaxSize) then
    raise ELandrixGaebError.Create('input of ' + IntToStr(ASize) +
      ' bytes exceeds the size limit of ' + IntToStr(SizeLimit(AMaxSize)) + ' bytes');
end;

function LandrixGaebDA2000ReadMapped(Buffer: Pointer; Size: Integer; AMaxSize: Int64;
  ACharset: TLandrixGaebCharset; ADiagnostics: TLandrixGaebDiagnostics; AInvalidTotals: TObjectList;
  out ADetection: TLandrixGaebDetection; out ATarget: TLandrixGaebTarget): TLandrixGaebXmlGAEB;
var
  Own: TLandrixGaebDiagnostics;
  I: TLandrixGaebListIndex;
  D: TLandrixGaebDiagnostic;
  Msg: string;
  Doc: TLandrixGaebDA2000Document;
begin
  CheckSize(Size, AMaxSize);
  Own := TLandrixGaebDiagnostics.Create;
  try
    ADetection := LandrixGaebDetectBuffer(Buffer, Size, False, Own);
    if not ADetection.Accepted or (ADetection.Format <> gfDA2000) then
    begin
      { the rule only: messages of the detection may name values of the
        input }
      Msg := 'input is not a readable GAEB DA 2000 file';
      for I := 0 to Own.Count - 1 do
        if Own[I].Severity >= gsError then
        begin
          Msg := Msg + ' (' + Own[I].RuleId + ')';
          Break;
        end;
      raise ELandrixGaebError.Create(Msg);
    end;
    { the parser reports the character set itself, in more detail }
    if ADiagnostics <> nil then
      for I := 0 to Own.Count - 1 do
      begin
        D := Own[I];
        if (D.RuleId <> 'GAEB-DET-014') and (D.RuleId <> 'GAEB-DET-015') then
          ADiagnostics.AddAt(D.RuleId, D.Severity, D.Path, D.Line, D.Column, D.Offset, D.Message);
      end;
  finally
    Own.Free;
  end;
  Doc := LandrixGaebDA2000Parse(Buffer, Size, ACharset, ADiagnostics);
  try
    Result := LandrixGaebDA2000Map(Doc, ADiagnostics, AInvalidTotals, ATarget);
  finally
    Doc.Free;
  end;
end;

function LandrixGaebDA2000ReadMappedStream(AStream: TStream; AMaxSize: Int64;
  ACharset: TLandrixGaebCharset; ADiagnostics: TLandrixGaebDiagnostics; AInvalidTotals: TObjectList;
  out ADetection: TLandrixGaebDetection; out ATarget: TLandrixGaebTarget): TLandrixGaebXmlGAEB;
var
  Remaining: Int64;
  Buffer: AnsiString;
  Count: Integer;
begin
  Remaining := AStream.Size - AStream.Position;
  CheckSize(Remaining, AMaxSize);
  Count := Integer(Remaining);
  Buffer := '';
  SetLength(Buffer, Count);
  if Count > 0 then
    AStream.ReadBuffer(Buffer[1], Count);
  Result := LandrixGaebDA2000ReadMapped(Pointer(Buffer), Count, AMaxSize, ACharset, ADiagnostics,
    AInvalidTotals, ADetection, ATarget);
end;

end.
