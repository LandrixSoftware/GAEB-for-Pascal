{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Content model check of GAEB DA XML documents (stage 2): checks a document
  against the grammar of its target (LandrixGaebXmlGrammar), generated from
  the schemas of the published targets. Checked are the namespace of every
  element, order, cardinality and choices of child elements (one automaton
  per content model), mandatory and unknown attributes, text in element
  content, simple values with all facets of their type (patterns,
  enumerations, lengths, digits, bounds; through LandrixXmlXsdTypes) and
  ID/IDREF (unique IDs, every IDREF names an ID). This is not a general
  XSD validator: it knows exactly the schemas of the grammar. The external
  validation against the original schemas stays the reference (plan 6.1,
  stage 5).

  An element that is not allowed is reported once; if the content model
  knows it, the check goes on at the nearest state that accepts it (missing
  mandatory elements are reported this way, on the element after the gap),
  and returns to the state before that jump when the next element fits
  there (an element out of order). Not checked: identity constraints
  (xs:unique), fixed and default values; IDs inside skipped elements are
  not collected.

  Diagnostics (rule identifiers, all errors; texts hold element, attribute
  and namespace names, never values of the document):
    GAEB-CHK-001  element not allowed at this place (order, cardinality,
                  choice, unknown element, element in simple content)
    GAEB-CHK-002  content of an element incomplete (mandatory element
                  missing)
    GAEB-CHK-003  element or attribute of another namespace
    GAEB-CHK-004  unknown attribute
    GAEB-CHK-005  mandatory attribute missing
    GAEB-CHK-006  invalid value (the XSD code, for example
                  cvc-maxLength-valid, is part of the message)
    GAEB-CHK-007  text in element-only content
    GAEB-CHK-008  ID used twice
    GAEB-CHK-009  IDREF without element of that ID
    GAEB-CHK-010  wrong root element

  DE: Pruefung der Inhaltsmodelle von GAEB-DA-XML-Dokumenten (Stufe 2):
  prueft ein Dokument gegen die Grammatik seines Ziels
  (LandrixGaebXmlGrammar), generiert aus den Schemas der veroeffentlichten
  Ziele. Geprueft werden der Namespace jedes Elements, Reihenfolge,
  Kardinalitaet und Auswahl der Kindelemente (ein Automat je
  Inhaltsmodell), Pflicht- und unbekannte Attribute, Text in reinem
  Elementinhalt, einfache Werte mit allen Facetten ihres Typs (Muster,
  Aufzaehlungen, Laengen, Stellen, Grenzen; ueber LandrixXmlXsdTypes) und
  ID/IDREF (eindeutige IDs, jede IDREF nennt eine ID). Das ist kein
  allgemeiner XSD-Validator: Er kennt genau die Schemas der Grammatik.
  Massstab bleibt die externe Validierung gegen die Originalschemas (Plan
  6.1, Stufe 5).

  Ein nicht erlaubtes Element wird einmal gemeldet; kennt das
  Inhaltsmodell es, geht die Pruefung am naechsten Zustand weiter, der es
  annimmt (fehlende Pflichtelemente werden so am Element nach der Luecke
  gemeldet), und kehrt zum Zustand vor diesem Sprung zurueck, wenn das
  naechste Element dort passt (ein Element ausser der Reihe). Nicht
  geprueft: Identitaetsbedingungen (xs:unique), feste und Vorgabewerte; IDs
  in uebersprungenen Elementen werden nicht erfasst. Die Regelkennungen
  oben gelten unveraendert; alle sind Fehler, die Texte sind englisch und
  enthalten Element-, Attribut- und Namespace-Namen, nie Werte des
  Dokuments. }

{ API: internal. May change in any release before 1.0.
  DE: API: intern. Kann sich vor Version 1.0 in jeder Version aendern. }

unit LandrixGaebXmlCheck;

{$I LandrixGaeb.inc}

interface

uses
  SysUtils,
  Classes,
  LandrixXmlBase,
  LandrixGaebTypes,
  LandrixGaebDiagnostics,
  LandrixGaebDetect,
  LandrixGaebXmlModel;

{ Checks a document in a buffer against the target it declares (detected as
  by the reader). True if no error was found. Targets without grammar raise
  ELandrixGaebError, input that is not well-formed ELandrixXmlError.
  ADiagnostics may be nil.
  DE: Prueft ein Dokument in einem Puffer gegen das Ziel, das es angibt
  (erkannt wie beim Leser). True, wenn kein Fehler gefunden wurde. Ziele
  ohne Grammatik loesen ELandrixGaebError aus, nicht wohlgeformte Eingaben
  ELandrixXmlError. ADiagnostics darf nil sein. }
function LandrixGaebXmlCheckBuffer(Buffer: Pointer; Size: Integer;
  ADiagnostics: TLandrixGaebDiagnostics; out ADetection: TLandrixGaebDetection): Boolean;

{ Checks a stream (current position to the end). AMaxSize <= 0 means
  LandrixGaebDefaultMaxSize.
  DE: Prueft einen Stream (aktuelle Position bis zum Ende). AMaxSize <= 0
  bedeutet LandrixGaebDefaultMaxSize. }
function LandrixGaebXmlCheckStream(AStream: TStream; ADiagnostics: TLandrixGaebDiagnostics;
  AMaxSize: Int64; out ADetection: TLandrixGaebDetection): Boolean;

{ Checks a file. DE: Prueft eine Datei. }
function LandrixGaebXmlCheckFile(const AFileName: string; ADiagnostics: TLandrixGaebDiagnostics;
  AMaxSize: Int64; out ADetection: TLandrixGaebDetection): Boolean;

{ Checks a document in a buffer against ATarget without detection (for
  output of the writer) and returns the number of errors.
  DE: Prueft ein Dokument in einem Puffer ohne Erkennung gegen ATarget
  (fuer Ausgaben des Schreibers) und liefert die Zahl der Fehler. }
function LandrixGaebXmlCheckTarget(Buffer: Pointer; Size: Integer;
  const ATarget: TLandrixGaebTarget; ADiagnostics: TLandrixGaebDiagnostics): Integer;

{ Checks a model against ATarget: writes it (mode gwmNormal, nothing is
  raised for problems) and checks the output. True if neither the writer
  (members the target does not allow, decimals with too many digits) nor
  the check found an error.
  DE: Prueft ein Modell gegen ATarget: schreibt es (Modus gwmNormal, fuer
  Probleme wird nichts ausgeloest) und prueft die Ausgabe. True, wenn weder
  der Schreiber (Mitglieder, die das Ziel nicht erlaubt, Dezimale mit zu
  vielen Stellen) noch die Pruefung einen Fehler gefunden hat. }
function LandrixGaebXmlCheckModel(ADocument: TLandrixGaebXmlGAEB; const ATarget: TLandrixGaebTarget;
  ADiagnostics: TLandrixGaebDiagnostics): Boolean;

implementation

uses
  Contnrs,
  LandrixXmlReader,
  LandrixXmlXsdTypes,
  LandrixGaebXmlGrammar,
  LandrixGaebXmlWriteBase,
  LandrixGaebXmlWriter;

const
  NamespaceXmlns = 'http://www.w3.org/2000/xmlns/';
  NamespaceXml = 'http://www.w3.org/XML/1998/namespace';
  NamespaceXsi = 'http://www.w3.org/2001/XMLSchema-instance';
  { names listed in "expected ..." }
  MaxExpected = 8;

type
  { An open element. ChildNames/ChildCounts count the children by name for
    the sibling index in paths. }
  TCheckFrame = record
    TypeRow: Integer;
    State: Integer;
    { state before the last resync, -1 if none }
    Fallback: Integer;
    Name: TLandrixXmlUtf8;
    Index: Integer;
    Text: TLandrixXmlUtf8;
    TextReported: Boolean;
    ChildNames: array of TLandrixXmlUtf8;
    ChildCounts: array of Integer;
    ChildKinds: Integer;
  end;

  { An IDREF whose ID was not seen yet. }
  TPendingRef = record
    Value: TLandrixXmlUtf8;
    Path: TLandrixGaebString;
    Line: Integer;
    Column: Integer;
    Offset: Int64;
  end;

  TUtf8Array = array of TLandrixXmlUtf8;
  TBooleanArray = array of Boolean;

  { Set of byte strings (open addressing; TStringList would compare
    locale-dependent and convert UTF-8 under Delphi 6). }
  TUtf8Set = class(TObject)
  private
    FSlots: TUtf8Array;
    FUsed: TBooleanArray;
    FCount: Integer;
    function Find(const S: TLandrixXmlUtf8): Integer;
    procedure Grow;
  public
    constructor Create;
    { False if S was already in the set. }
    function Add(const S: TLandrixXmlUtf8): Boolean;
    function Contains(const S: TLandrixXmlUtf8): Boolean;
  end;

  TChecker = class(TObject)
  private
    FReader: TLandrixXmlReader;
    FNamespace: TLandrixXmlUtf8;
    FDiagnostics: TLandrixGaebDiagnostics;
    FErrors: Integer;
    FFrames: array of TCheckFrame;
    FDepth: Integer;
    FSimples: array of TLandrixXmlXsdSimpleType;
    FOwned: TObjectList;
    FIdType: TLandrixXmlXsdSimpleType;
    FIdRefType: TLandrixXmlXsdSimpleType;
    FIds: TUtf8Set;
    FRefs: array of TPendingRef;
    FRefCount: Integer;
    function Path(const AChild: TLandrixXmlUtf8; AChildIndex: Integer): TLandrixGaebString;
    procedure Report(const ARuleId, AMessage: string);
    procedure ReportChild(const AChild: TLandrixXmlUtf8; AChildIndex: Integer;
      const ARuleId, AMessage: string);
    function SimpleType(ARow: Integer): TLandrixXmlXsdSimpleType;
    procedure CheckValue(ARow: Integer; const AText: TLandrixXmlUtf8; const AWhere: string);
    procedure CheckAttributes(ATypeRow: Integer);
    function Expected(AState: Integer): string;
    function SiblingIndex(AFrame: Integer; const AName: TLandrixXmlUtf8): Integer;
    function Find(AState, AName: Integer): Integer;
    function Resync(AState, AName: Integer): Integer;
    procedure Push(ATypeRow: Integer; const AName: TLandrixXmlUtf8; AIndex: Integer);
    procedure StartChild;
    procedure EndElement;
    procedure Text;
    procedure ResolveRefs;
  public
    constructor Create(AReader: TLandrixXmlReader; const ANamespace: TLandrixXmlUtf8;
      ADiagnostics: TLandrixGaebDiagnostics);
    destructor Destroy; override;
    procedure Run(ARootType: Integer);
    property Errors: Integer read FErrors;
  end;

function SpanCompare(const ASpan: TLandrixXmlSpan; const AName: TLandrixXmlUtf8): Integer;
var
  I, N: Integer;
begin
  N := Length(AName);
  I := 0;
  while (I < ASpan.Len) and (I < N) do
  begin
    if ASpan.P[I] <> AName[I + 1] then
    begin
      Result := Ord(ASpan.P[I]) - Ord(AName[I + 1]);
      Exit;
    end;
    Inc(I);
  end;
  Result := ASpan.Len - N;
end;

{ Index of a name in LandrixGaebXmlGrammarNames, -1 if the grammar does not
  know it. }
function NameIndex(const ASpan: TLandrixXmlSpan): Integer;
var
  Lo, Hi, C: Integer;
begin
  Lo := 0;
  Hi := High(LandrixGaebXmlGrammarNames);
  while Lo <= Hi do
  begin
    Result := (Lo + Hi) div 2;
    C := SpanCompare(ASpan, LandrixGaebXmlGrammarNames[Result]);
    if C = 0 then
      Exit;
    if C < 0 then
      Hi := Result - 1
    else
      Lo := Result + 1;
  end;
  Result := -1;
end;

{ True if S holds XML whitespace only (the reader does not tell for CDATA). }
function IsBlank(const S: TLandrixXmlUtf8): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to Length(S) do
    if not (S[I] in [#9, #10, #13, ' ']) then
      Exit;
  Result := True;
end;

{ TUtf8Set }

constructor TUtf8Set.Create;
begin
  inherited Create;
  SetLength(FSlots, 64);
  SetLength(FUsed, 64);
end;

function TUtf8Set.Find(const S: TLandrixXmlUtf8): Integer;
var
  H: Cardinal;
  I, Mask: Integer;
begin
  { FNV-1a; the product in Int64 (32 x 24 bits) cannot overflow in checked
    builds. Rotate and xor clustered IDs such as I1..I99999 (four of eight
    bits per digit) and made the probing quadratic. }
  H := 2166136261;
  for I := 1 to Length(S) do
    H := Cardinal((Int64(H xor Cardinal(Ord(S[I]))) * 16777619) and $FFFFFFFF);
  Mask := Integer(Length(FSlots)) - 1;
  Result := Integer(H and Cardinal(Mask));
  while FUsed[Result] and (FSlots[Result] <> S) do
    Result := (Result + 1) and Mask;
end;

procedure TUtf8Set.Grow;
var
  OldSlots: TUtf8Array;
  OldUsed: TBooleanArray;
  I, J: Integer;
begin
  OldSlots := FSlots;
  OldUsed := FUsed;
  FSlots := nil;
  FUsed := nil;
  SetLength(FSlots, Length(OldSlots) * 2);
  SetLength(FUsed, Length(OldSlots) * 2);
  for I := 0 to Integer(High(OldSlots)) do
    if OldUsed[I] then
    begin
      J := Find(OldSlots[I]);
      FSlots[J] := OldSlots[I];
      FUsed[J] := True;
    end;
end;

function TUtf8Set.Add(const S: TLandrixXmlUtf8): Boolean;
var
  I: Integer;
begin
  if (FCount + 1) * 2 > Length(FSlots) then
    Grow;
  I := Find(S);
  Result := not FUsed[I];
  if Result then
  begin
    FSlots[I] := S;
    FUsed[I] := True;
    Inc(FCount);
  end;
end;

function TUtf8Set.Contains(const S: TLandrixXmlUtf8): Boolean;
begin
  Result := FUsed[Find(S)];
end;

{ TChecker }

constructor TChecker.Create(AReader: TLandrixXmlReader; const ANamespace: TLandrixXmlUtf8;
  ADiagnostics: TLandrixGaebDiagnostics);
begin
  inherited Create;
  FReader := AReader;
  FNamespace := ANamespace;
  FDiagnostics := ADiagnostics;
  FOwned := TObjectList.Create;
  SetLength(FSimples, Length(LandrixGaebXmlGrammarSimples));
  FIdType := LandrixXmlXsdBuiltinType('ID');
  FIdRefType := LandrixXmlXsdBuiltinType('IDREF');
  FIds := TUtf8Set.Create;
end;

destructor TChecker.Destroy;
begin
  FIds.Free;
  FOwned.Free;
  inherited Destroy;
end;

function TChecker.Path(const AChild: TLandrixXmlUtf8; AChildIndex: Integer): TLandrixGaebString;
var
  S: TLandrixXmlUtf8;
  I: Integer;
begin
  S := '';
  for I := 0 to FDepth - 1 do
    S := S + '/' + FFrames[I].Name + '[' + LandrixXmlStringToUtf8(IntToStr(FFrames[I].Index)) + ']';
  if AChild <> '' then
    S := S + '/' + AChild + '[' + LandrixXmlStringToUtf8(IntToStr(AChildIndex)) + ']';
  Result := LandrixXmlUtf8ToWide(S);
end;

procedure TChecker.ReportChild(const AChild: TLandrixXmlUtf8; AChildIndex: Integer;
  const ARuleId, AMessage: string);
begin
  Inc(FErrors);
  if FDiagnostics <> nil then
    FDiagnostics.AddAt(ARuleId, gsError, Path(AChild, AChildIndex), FReader.Line,
      FReader.Column, FReader.Offset, AMessage);
end;

procedure TChecker.Report(const ARuleId, AMessage: string);
begin
  ReportChild('', 0, ARuleId, AMessage);
end;

function TChecker.SimpleType(ARow: Integer): TLandrixXmlXsdSimpleType;
var
  Row: TLandrixGaebXmlGrammarSimple;
  Members: TLandrixXmlXsdSimpleTypeArray;
  I: Integer;
begin
  Result := FSimples[ARow];
  if Result <> nil then
    Exit;
  Row := LandrixGaebXmlGrammarSimples[ARow];
  if Row.Builtin >= 0 then
  begin
    Result := LandrixXmlXsdBuiltinType(LandrixGaebXmlGrammarTexts[Row.Builtin]);
    if Result = nil then
      raise ELandrixGaebError.Create('grammar: unknown built-in type ' +
        LandrixXmlUtf8ToString(LandrixGaebXmlGrammarTexts[Row.Builtin]));
  end
  else if Row.Union then
  begin
    Members := nil;
    SetLength(Members, Row.Count);
    for I := 0 to Row.Count - 1 do
      Members[I] := SimpleType(LandrixGaebXmlGrammarMembers[Row.First + I]);
    Result := TLandrixXmlXsdSimpleType.CreateUnion(Members, '', '');
    FOwned.Add(Result);
  end
  else
  begin
    Result := TLandrixXmlXsdSimpleType.CreateRestriction(SimpleType(Row.Base), '', '');
    FOwned.Add(Result);
    for I := Row.First to Row.First + Row.Count - 1 do
      Result.AddFacet(LandrixGaebXmlGrammarFacets[I].Facet,
        LandrixGaebXmlGrammarTexts[LandrixGaebXmlGrammarFacets[I].Value]);
  end;
  FSimples[ARow] := Result;
end;

procedure TChecker.CheckValue(ARow: Integer; const AText: TLandrixXmlUtf8; const AWhere: string);
var
  T: TLandrixXmlXsdSimpleType;
  Value: TLandrixXmlXsdValue;
  Error: TLandrixXmlXsdError;
begin
  T := SimpleType(ARow);
  if not T.Validate(AText, Value, Error) then
    Report('GAEB-CHK-006', 'invalid value' + AWhere + ' (' + Error.Code + ')')
  else if T.IsDerivedFrom(FIdType) then
  begin
    if not FIds.Add(Value.Text) then
      Report('GAEB-CHK-008', 'ID' + AWhere + ' used twice');
  end
  else if T.IsDerivedFrom(FIdRefType) and not FIds.Contains(Value.Text) then
  begin
    if FRefCount >= Length(FRefs) then
      SetLength(FRefs, FRefCount * 2 + 16);
    FRefs[FRefCount].Value := Value.Text;
    FRefs[FRefCount].Path := Path('', 0);
    FRefs[FRefCount].Line := FReader.Line;
    FRefs[FRefCount].Column := FReader.Column;
    FRefs[FRefCount].Offset := FReader.Offset;
    Inc(FRefCount);
  end;
end;

procedure TChecker.CheckAttributes(ATypeRow: Integer);
var
  T: TLandrixGaebXmlGrammarType;
  Seen: array of Boolean;
  I, J: Integer;
  Ns, Name: TLandrixXmlUtf8;
begin
  T := LandrixGaebXmlGrammarTypes[ATypeRow];
  Seen := nil;
  SetLength(Seen, T.Count);
  for I := 0 to FReader.AttributeCount - 1 do
  begin
    if FReader.AttributeNamespaceUriSpan(I).Len > 0 then
    begin
      Ns := FReader.AttributeNamespaceUriUtf8(I);
      if (Ns <> NamespaceXmlns) and (Ns <> NamespaceXml) and (Ns <> NamespaceXsi) then
        Report('GAEB-CHK-003', 'attribute ' + LandrixXmlUtf8ToString(FReader.AttributeLocalNameUtf8(I)) +
          ' of namespace ' + LandrixXmlUtf8ToString(Ns) + ' not allowed');
      Continue;
    end;
    J := 0;
    while (J < T.Count) and not LandrixXmlSpanEquals(FReader.AttributeLocalNameSpan(I),
      LandrixGaebXmlGrammarNames[LandrixGaebXmlGrammarAttrs[T.First + J].Name]) do
      Inc(J);
    Name := FReader.AttributeLocalNameUtf8(I);
    if J >= T.Count then
      Report('GAEB-CHK-004', 'unknown attribute ' + LandrixXmlUtf8ToString(Name))
    else
    begin
      Seen[J] := True;
      CheckValue(LandrixGaebXmlGrammarAttrs[T.First + J].Simple, FReader.AttributeValueUtf8(I),
        ' of attribute ' + LandrixXmlUtf8ToString(Name));
    end;
  end;
  for J := 0 to T.Count - 1 do
    if LandrixGaebXmlGrammarAttrs[T.First + J].Required and not Seen[J] then
      Report('GAEB-CHK-005', 'mandatory attribute ' + LandrixXmlUtf8ToString(
        LandrixGaebXmlGrammarNames[LandrixGaebXmlGrammarAttrs[T.First + J].Name]) + ' missing');
end;

function TChecker.Expected(AState: Integer): string;
var
  S: TLandrixGaebXmlGrammarState;
  I: Integer;
begin
  S := LandrixGaebXmlGrammarStates[AState];
  Result := '';
  for I := 0 to S.Count - 1 do
    if I < MaxExpected then
    begin
      if Result <> '' then
        Result := Result + ', ';
      Result := Result + LandrixXmlUtf8ToString(
        LandrixGaebXmlGrammarNames[LandrixGaebXmlGrammarTransitions[S.First + I].Name]);
    end;
  if S.Count > MaxExpected then
    Result := Result + ', ...';
  if S.Final then
  begin
    if Result <> '' then
      Result := Result + ' or ';
    Result := Result + 'end of element';
  end;
end;

function TChecker.SiblingIndex(AFrame: Integer; const AName: TLandrixXmlUtf8): Integer;
var
  I, N: Integer;
begin
  N := FFrames[AFrame].ChildKinds;
  for I := 0 to N - 1 do
    if FFrames[AFrame].ChildNames[I] = AName then
    begin
      Inc(FFrames[AFrame].ChildCounts[I]);
      Result := FFrames[AFrame].ChildCounts[I];
      Exit;
    end;
  if N >= Length(FFrames[AFrame].ChildNames) then
  begin
    SetLength(FFrames[AFrame].ChildNames, N * 2 + 4);
    SetLength(FFrames[AFrame].ChildCounts, N * 2 + 4);
  end;
  FFrames[AFrame].ChildNames[N] := AName;
  FFrames[AFrame].ChildCounts[N] := 1;
  FFrames[AFrame].ChildKinds := N + 1;
  Result := 1;
end;

{ After an element that is not allowed in AState: the transition on AName
  from the nearest state reachable from AState (as if the elements in
  between were present), -1 if there is none. The check then goes on there
  instead of reporting every following sibling. }
function TChecker.Find(AState, AName: Integer): Integer;
var
  S: TLandrixGaebXmlGrammarState;
begin
  S := LandrixGaebXmlGrammarStates[AState];
  Result := S.First;
  while (Result < S.First + S.Count) and (LandrixGaebXmlGrammarTransitions[Result].Name <> AName) do
    Inc(Result);
  if Result >= S.First + S.Count then
    Result := -1;
end;

function TChecker.Resync(AState, AName: Integer): Integer;
var
  Seen: array of Boolean;
  Queue: array of Integer;
  Head, Tail, S, I: Integer;
  St: TLandrixGaebXmlGrammarState;
begin
  Seen := nil;
  Queue := nil;
  SetLength(Seen, Length(LandrixGaebXmlGrammarStates));
  SetLength(Queue, Length(LandrixGaebXmlGrammarStates));
  Seen[AState] := True;
  Queue[0] := AState;
  Head := 0;
  Tail := 1;
  while Head < Tail do
  begin
    S := Queue[Head];
    Inc(Head);
    St := LandrixGaebXmlGrammarStates[S];
    if S <> AState then
      for I := St.First to St.First + St.Count - 1 do
        if LandrixGaebXmlGrammarTransitions[I].Name = AName then
        begin
          Result := I;
          Exit;
        end;
    for I := St.First to St.First + St.Count - 1 do
      if not Seen[LandrixGaebXmlGrammarTransitions[I].Next] then
      begin
        Seen[LandrixGaebXmlGrammarTransitions[I].Next] := True;
        Queue[Tail] := LandrixGaebXmlGrammarTransitions[I].Next;
        Inc(Tail);
      end;
  end;
  Result := -1;
end;

procedure TChecker.Push(ATypeRow: Integer; const AName: TLandrixXmlUtf8; AIndex: Integer);
begin
  if FDepth >= Length(FFrames) then
    SetLength(FFrames, FDepth * 2 + 8);
  FFrames[FDepth].TypeRow := ATypeRow;
  FFrames[FDepth].State := LandrixGaebXmlGrammarTypes[ATypeRow].Start;
  FFrames[FDepth].Fallback := -1;
  FFrames[FDepth].Name := AName;
  FFrames[FDepth].Index := AIndex;
  FFrames[FDepth].Text := '';
  FFrames[FDepth].TextReported := False;
  FFrames[FDepth].ChildKinds := 0;
  Inc(FDepth);
end;

procedure TChecker.StartChild;
var
  Parent, Index, N, I: Integer;
  Name: TLandrixXmlUtf8;
  T: TLandrixGaebXmlGrammarType;
  Tr: TLandrixGaebXmlGrammarTrans;
begin
  Parent := FDepth - 1;
  Name := FReader.LocalNameUtf8;
  Index := SiblingIndex(Parent, Name);
  if not LandrixXmlSpanEquals(FReader.NamespaceUriSpan, FNamespace) then
  begin
    if FReader.NamespaceUriSpan.Len = 0 then
      ReportChild(Name, Index, 'GAEB-CHK-003', 'element without namespace not allowed')
    else
      ReportChild(Name, Index, 'GAEB-CHK-003', 'element of namespace ' +
        LandrixXmlUtf8ToString(FReader.NamespaceUriUtf8) + ' not allowed');
    FReader.Skip;
    Exit;
  end;
  T := LandrixGaebXmlGrammarTypes[FFrames[Parent].TypeRow];
  if T.Start < 0 then
  begin
    ReportChild(Name, Index, 'GAEB-CHK-001', 'element ' + LandrixXmlUtf8ToString(Name) +
      ' not allowed; ' + LandrixXmlUtf8ToString(FFrames[Parent].Name) + ' has no child elements');
    FReader.Skip;
    Exit;
  end;
  N := NameIndex(FReader.LocalNameSpan);
  I := -1;
  if N >= 0 then
    I := Find(FFrames[Parent].State, N);
  if (I < 0) and (N >= 0) and (FFrames[Parent].Fallback >= 0) then
    { the element fits where the check stood before the last resync: that
      resync skipped too far (an element out of order), go on from there }
    I := Find(FFrames[Parent].Fallback, N);
  FFrames[Parent].Fallback := -1;
  if I < 0 then
  begin
    ReportChild(Name, Index, 'GAEB-CHK-001', 'element ' + LandrixXmlUtf8ToString(Name) +
      ' not allowed here; expected ' + Expected(FFrames[Parent].State));
    if N >= 0 then
      I := Resync(FFrames[Parent].State, N);
    if I < 0 then
    begin
      FReader.Skip;
      Exit;
    end;
    FFrames[Parent].Fallback := FFrames[Parent].State;
  end;
  Tr := LandrixGaebXmlGrammarTransitions[I];
  FFrames[Parent].State := Tr.Next;
  Push(Tr.ElementType, Name, Index);
  CheckAttributes(Tr.ElementType);
end;

procedure TChecker.EndElement;
var
  T: TLandrixGaebXmlGrammarType;
  Top: Integer;
begin
  Top := FDepth - 1;
  T := LandrixGaebXmlGrammarTypes[FFrames[Top].TypeRow];
  if (T.Start >= 0) and not LandrixGaebXmlGrammarStates[FFrames[Top].State].Final then
    Report('GAEB-CHK-002', 'element ' + LandrixXmlUtf8ToString(FFrames[Top].Name) +
      ' incomplete; expected ' + Expected(FFrames[Top].State));
  if T.Simple >= 0 then
    CheckValue(T.Simple, FFrames[Top].Text, '');
  FFrames[Top].Text := '';
  Dec(FDepth);
end;

procedure TChecker.Text;
var
  T: TLandrixGaebXmlGrammarType;
  Top: Integer;
begin
  Top := FDepth - 1;
  if Top < 0 then
    Exit;
  T := LandrixGaebXmlGrammarTypes[FFrames[Top].TypeRow];
  if T.Simple >= 0 then
    FFrames[Top].Text := FFrames[Top].Text + FReader.ValueUtf8
  else if not T.Mixed and not FFrames[Top].TextReported and not FReader.IsWhitespace and
    not ((FReader.TokenType = xttCData) and IsBlank(FReader.ValueUtf8)) then
  begin
    FFrames[Top].TextReported := True;
    Report('GAEB-CHK-007', 'text not allowed in element content');
  end;
end;

procedure TChecker.ResolveRefs;
var
  I: Integer;
begin
  for I := 0 to FRefCount - 1 do
    if not FIds.Contains(FRefs[I].Value) then
    begin
      Inc(FErrors);
      if FDiagnostics <> nil then
        FDiagnostics.AddAt('GAEB-CHK-009', gsError, FRefs[I].Path, FRefs[I].Line,
          FRefs[I].Column, FRefs[I].Offset, 'IDREF without element of that ID');
    end;
end;

procedure TChecker.Run(ARootType: Integer);
begin
  while (FReader.TokenType <> xttStartElement) and FReader.Read do
    ;
  if FReader.TokenType <> xttStartElement then
  begin
    Report('GAEB-CHK-010', 'no root element');
    Exit;
  end;
  if not LandrixXmlSpanEquals(FReader.NamespaceUriSpan, FNamespace) or
    not LandrixXmlSpanEquals(FReader.LocalNameSpan, LandrixGaebXmlGrammarRootName) then
  begin
    Report('GAEB-CHK-010', 'root element must be ' + LandrixGaebXmlGrammarRootName +
      ' of namespace ' + LandrixXmlUtf8ToString(FNamespace));
    Exit;
  end;
  Push(ARootType, FReader.LocalNameUtf8, 1);
  CheckAttributes(ARootType);
  while FReader.Read do
    case FReader.TokenType of
      xttStartElement:
        StartChild;
      xttEndElement:
        EndElement;
      xttText, xttCData:
        Text;
    else
      ;
    end;
  ResolveRefs;
end;

{ public functions }

function GrammarRoot(const ATarget: TLandrixGaebTarget): Integer;
begin
  Result := LandrixGaebXmlGrammarRoot(ATarget);
  if (Result < 0) or not LandrixGaebTargetIsSupported(ATarget, False) then
    raise ELandrixGaebError.Create('GAEB DA XML ' +
      LandrixXmlUtf8ToString(LandrixGaebVersionToText(ATarget.Version)) + ' ' +
      LandrixXmlUtf8ToString(LandrixGaebEditionToText(ATarget.Edition)) + ' DA' +
      LandrixXmlUtf8ToString(LandrixGaebPhaseToDP(ATarget.Phase)) +
      ' is not supported for checking');
end;

function CheckRoot(Buffer: Pointer; Size: Integer; const ANamespace: TLandrixXmlUtf8;
  ARootType: Integer; ADiagnostics: TLandrixGaebDiagnostics): Integer;
var
  Reader: TLandrixXmlReader;
  Checker: TChecker;
begin
  Reader := TLandrixXmlReader.Create;
  try
    Reader.LoadFromBuffer(PAnsiChar(Buffer)^, Size);
    Checker := TChecker.Create(Reader, ANamespace, ADiagnostics);
    try
      Checker.Run(ARootType);
      Result := Checker.Errors;
    finally
      Checker.Free;
    end;
  finally
    Reader.Free;
  end;
end;

function RejectMessage(ADiagnostics: TLandrixGaebDiagnostics; AFirst: Integer): string;
var
  I: TLandrixGaebListIndex;
begin
  Result := 'input is not a readable GAEB DA XML document';
  for I := AFirst to ADiagnostics.Count - 1 do
    if ADiagnostics[I].Severity >= gsError then
    begin
      Result := Result + ': [' + ADiagnostics[I].RuleId + '] ' + ADiagnostics[I].Message;
      Exit;
    end;
end;

function LandrixGaebXmlCheckBuffer(Buffer: Pointer; Size: Integer;
  ADiagnostics: TLandrixGaebDiagnostics; out ADetection: TLandrixGaebDetection): Boolean;
var
  Diags: TLandrixGaebDiagnostics;
  First, Root: Integer;
begin
  Diags := ADiagnostics;
  if Diags = nil then
    Diags := TLandrixGaebDiagnostics.Create;
  try
    First := Integer(Diags.Count);
    ADetection := LandrixGaebDetectBuffer(Buffer, Size, False, Diags);
    if not ADetection.Accepted or (ADetection.Format <> gfXml) then
      raise ELandrixGaebError.Create(RejectMessage(Diags, First));
  finally
    if ADiagnostics = nil then
      Diags.Free;
  end;
  Root := GrammarRoot(ADetection.Target);
  Result := CheckRoot(Buffer, Size, ADetection.Namespace, Root, ADiagnostics) = 0;
end;

function LandrixGaebXmlCheckStream(AStream: TStream; ADiagnostics: TLandrixGaebDiagnostics;
  AMaxSize: Int64; out ADetection: TLandrixGaebDetection): Boolean;
var
  Remaining: Int64;
  Buffer: AnsiString;
  Count: Integer;
begin
  if AMaxSize <= 0 then
    AMaxSize := LandrixGaebDefaultMaxSize;
  if AMaxSize > MaxInt then
    AMaxSize := MaxInt;
  Remaining := AStream.Size - AStream.Position;
  if Remaining > AMaxSize then
    raise ELandrixGaebError.Create('input of ' + IntToStr(Remaining) +
      ' bytes exceeds the size limit of ' + IntToStr(AMaxSize) + ' bytes');
  Count := Integer(Remaining);
  Buffer := '';
  SetLength(Buffer, Count);
  if Count > 0 then
    AStream.ReadBuffer(Buffer[1], Count);
  Result := LandrixGaebXmlCheckBuffer(Pointer(Buffer), Count, ADiagnostics, ADetection);
end;

function LandrixGaebXmlCheckFile(const AFileName: string; ADiagnostics: TLandrixGaebDiagnostics;
  AMaxSize: Int64; out ADetection: TLandrixGaebDetection): Boolean;
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    Result := LandrixGaebXmlCheckStream(Stream, ADiagnostics, AMaxSize, ADetection);
  finally
    Stream.Free;
  end;
end;

function LandrixGaebXmlCheckTarget(Buffer: Pointer; Size: Integer;
  const ATarget: TLandrixGaebTarget; ADiagnostics: TLandrixGaebDiagnostics): Integer;
begin
  Result := CheckRoot(Buffer, Size, LandrixGaebTargetNamespace(ATarget), GrammarRoot(ATarget),
    ADiagnostics);
end;

function LandrixGaebXmlCheckModel(ADocument: TLandrixGaebXmlGAEB; const ATarget: TLandrixGaebTarget;
  ADiagnostics: TLandrixGaebDiagnostics): Boolean;
var
  Options: TLandrixGaebXmlWriteOptions;
  Errors, Warnings: Integer;
begin
  Options := LandrixGaebXmlDefaultWriteOptions;
  Options.Mode := gwmNormal;
  Options.Check := True;
  LandrixGaebXmlWriteCollect(ADocument, ATarget, Options, ADiagnostics, Errors, Warnings);
  Result := Errors = 0;
end;

end.
