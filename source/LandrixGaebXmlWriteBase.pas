{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Writing context of the generated GAEB DA XML writer
  (LandrixGaebXmlWriter): wraps the streaming writer of LandrixXml, the
  profile row of the target (LandrixGaebXmlProfiles) and the diagnostics.
  The writer never drops data silently: an element or attribute that the
  target schema does not have is an error, or in mode gwmBestEffort a
  warning saying that it was left out (loss report).

  Diagnostics (rule identifiers):
    GAEB-WRT-001 error/warning  element or attribute not allowed in the
                                target (left out)
    GAEB-WRT-002 error/warning  decimal with more fraction digits than the
                                target type allows (left out, never
                                rounded)
    GAEB-WRT-003 information    Version, VersDate or DP of the model
                                differs from the target and was replaced
    GAEB-WRT-004 error/warning  node of an ordered child list that does not
                                fit the container (text node, unknown
                                element name or wrong class; left out)

  DE: Schreibkontext des generierten GAEB-DA-XML-Schreibers
  (LandrixGaebXmlWriter): kapselt den Streaming-Writer von LandrixXml, die
  Profilzeile des Ziels (LandrixGaebXmlProfiles) und die Meldungen. Der
  Schreiber laesst nie stillschweigend Daten weg: Ein Element oder Attribut,
  das das Zielschema nicht hat, ist ein Fehler, im Modus gwmBestEffort eine
  Warnung, dass es weggelassen wurde (Verlustbericht). Die Regelkennungen
  oben gelten unveraendert; die Texte sind englisch und enthalten keine
  Werte. }

{ API: internal. May change in any release before 1.0.
  DE: API: intern. Kann sich vor Version 1.0 in jeder Version aendern. }

unit LandrixGaebXmlWriteBase;

{$I LandrixGaeb.inc}

interface

uses
  SysUtils,
  Classes,
  LandrixXmlBase,
  LandrixXmlWriter,
  LandrixGaebTypes,
  LandrixGaebDiagnostics,
  LandrixGaebXmlProfiles;

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

  { Options of a write. A record without methods (Delphi 6); start from
    LandrixGaebXmlDefaultWriteOptions.
    DE: Optionen eines Schreibvorgangs. Record ohne Methoden (Delphi 6);
    mit LandrixGaebXmlDefaultWriteOptions beginnen. }
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

  { One open element of a write: its name, its index among the siblings of
    that name (for diagnostic paths) and the names of its children written
    so far with their counts. Used by TLandrixGaebXmlWriteContext only.
    DE: Ein offenes Element eines Schreibvorgangs: Name, Index unter den
    gleichnamigen Geschwistern (fuer Pfade in Meldungen) und die Namen der
    bisher geschriebenen Kinder mit ihrer Anzahl. Nur von
    TLandrixGaebXmlWriteContext benutzt. }
  TLandrixGaebXmlWriteFrame = record
    Name: TLandrixXmlUtf8;
    Index: Integer;
    ChildNames: array of TLandrixXmlUtf8;
    ChildCounts: array of Integer;
    ChildCount: Integer;
  end;

  { State of one write. Used by the generated writer only.
    DE: Zustand eines Schreibvorgangs. Nur vom generierten Schreiber
    benutzt. }
  TLandrixGaebXmlWriteContext = class(TObject)
  private
    FWriter: TLandrixXmlWriter;
    FOptions: TLandrixGaebXmlWriteOptions;
    FDiagnostics: TLandrixGaebDiagnostics;
    { FFrames[0] is the document, FFrames[1..FDepth] the open elements;
      frames are reused, so writing allocates nothing per element }
    FFrames: array of TLandrixGaebXmlWriteFrame;
    FDepth: Integer;
    FErrors: Integer;
    FWarnings: Integer;
    FTargetVersion: TLandrixGaebString;
    FTargetVersDate: TLandrixGaebString;
    FTargetDP: TLandrixGaebString;
    FNamespace: TLandrixXmlUtf8;
    procedure Report(const ARuleId: string; ASeverity: TLandrixGaebSeverity;
      const AMessage: string);
    { error, or warning in mode gwmBestEffort }
    procedure Loss(const ARuleId, AMessage: string);
    function Path: TLandrixGaebString;
    procedure Enter(const AName: TLandrixXmlUtf8);
  public
    constructor Create(AWriter: TLandrixXmlWriter; const AOptions: TLandrixGaebXmlWriteOptions;
      const ATarget: TLandrixGaebTarget; ADiagnostics: TLandrixGaebDiagnostics);
    destructor Destroy; override;
    { Starts the root element in the namespace of the target.
      DE: Beginnt das Wurzelelement im Namespace des Ziels. }
    procedure StartRoot(const AName: TLandrixXmlUtf8);
    { Starts an element (in the namespace of the document). AMixed: text
      block without indentation.
      DE: Beginnt ein Element (im Namespace des Dokuments). AMixed:
      Textblock ohne Einrueckung. }
    procedure StartElement(const AName: TLandrixXmlUtf8; AMixed: Boolean);
    { Ends the current element. DE: Beendet das aktuelle Element. }
    procedure EndElement;
    { True if the slot allows a member; otherwise reports its loss.
      DE: True, wenn der Slot ein Mitglied erlaubt; sonst wird sein
      Verlust gemeldet. }
    function Allowed(ASlot: Integer; const AName: TLandrixXmlUtf8; AAttribute: Boolean): Boolean;
    { Profile row of the child of a slot. DE: Profilzeile des Kinds eines
      Slots. }
    function ChildRow(ASlot: Integer): Integer;
    { Simple element with text. DE: Einfaches Element mit Text. }
    procedure ValueText(ASlot: Integer; const AName: TLandrixXmlUtf8;
      const AValue: TLandrixGaebString);
    { Simple element with a bounded decimal. DE: Einfaches Element mit
      begrenzter Dezimalzahl. }
    procedure ValueDecimal(ASlot: Integer; const AName: TLandrixXmlUtf8;
      const AValue: TLandrixGaebDecimal);
    { Simple element with an unbounded decimal. DE: Einfaches Element mit
      unbegrenzter Dezimalzahl. }
    procedure ValueDecimalText(ASlot: Integer; const AName: TLandrixXmlUtf8;
      const AValue: TLandrixGaebDecimalText);
    { Attribute with text. DE: Attribut mit Text. }
    procedure AttrText(ASlot: Integer; const AName: TLandrixXmlUtf8;
      const AValue: TLandrixGaebString);
    { Attribute with a bounded decimal. DE: Attribut mit begrenzter
      Dezimalzahl. }
    procedure AttrDecimal(ASlot: Integer; const AName: TLandrixXmlUtf8;
      const AValue: TLandrixGaebDecimal);
    { Attribute with an unbounded decimal. DE: Attribut mit unbegrenzter
      Dezimalzahl. }
    procedure AttrDecimalText(ASlot: Integer; const AName: TLandrixXmlUtf8;
      const AValue: TLandrixGaebDecimalText);
    { Text content of the current element. DE: Textinhalt des aktuellen
      Elements. }
    procedure ContentText(const AValue: TLandrixGaebString);
    { Bounded decimal content (slot of the content). DE: Begrenzter
      Dezimalinhalt (Slot des Inhalts). }
    procedure ContentDecimal(ASlot: Integer; const AValue: TLandrixGaebDecimal);
    { Unbounded decimal content. DE: Unbegrenzter Dezimalinhalt. }
    procedure ContentDecimalText(const AValue: TLandrixGaebDecimalText);
    { UTF-8 text content (Base64). DE: UTF-8-Textinhalt (Base64). }
    procedure ContentUtf8(const AValue: TLandrixXmlUtf8);
    { The target value of Version, VersDate or DP; reports a different
      model value.
      DE: Der Zielwert von Version, VersDate oder DP; meldet einen
      abweichenden Modellwert. }
    function TargetVersion(const AModel: TLandrixGaebString): TLandrixGaebString;
    function TargetVersDate(const AModel: TLandrixGaebString): TLandrixGaebString;
    function TargetDP(const AModel: TLandrixGaebString): TLandrixGaebString;
    { Reports a node of an ordered child list that cannot be written.
      DE: Meldet einen Knoten einer geordneten Kinderliste, der nicht
      geschrieben werden kann. }
    procedure BadChild(const AName: TLandrixXmlUtf8);
    { Number of errors and warnings so far. DE: Bisherige Anzahl Fehler
      und Warnungen. }
    property Errors: Integer read FErrors;
    property Warnings: Integer read FWarnings;
    { The streaming writer. DE: Der Streaming-Writer. }
    property Writer: TLandrixXmlWriter read FWriter;
  end;

{ Default options: gwmNormal, decimals normalized to the target type,
  no BOM, indented, CR LF.
  DE: Standardoptionen: gwmNormal, Dezimale auf den Zieltyp normalisiert,
  keine BOM, eingerueckt, CR LF. }
function LandrixGaebXmlDefaultWriteOptions: TLandrixGaebXmlWriteOptions;

implementation

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

{ True for the elements of unit prices (UP, UPComp1 to UPComp6).
  DE: True fuer die Elemente der Einheitspreise (UP, UPComp1 bis
  UPComp6). }
function IsUnitPrice(const AName: TLandrixXmlUtf8): Boolean;
begin
  Result := (AName = 'UP') or ((Length(AName) = 7) and (Copy(AName, 1, 6) = 'UPComp') and
    (AName[7] >= '1') and (AName[7] <= '6'));
end;

{ TLandrixGaebXmlWriteContext }

constructor TLandrixGaebXmlWriteContext.Create(AWriter: TLandrixXmlWriter;
  const AOptions: TLandrixGaebXmlWriteOptions; const ATarget: TLandrixGaebTarget;
  ADiagnostics: TLandrixGaebDiagnostics);
begin
  inherited Create;
  FWriter := AWriter;
  FOptions := AOptions;
  FDiagnostics := ADiagnostics;
  SetLength(FFrames, 32);
  FDepth := 0;
  FTargetVersion := LandrixXmlUtf8ToWide(LandrixGaebVersionToText(ATarget.Version));
  FTargetVersDate := LandrixXmlUtf8ToWide(LandrixGaebTargetVersDate(ATarget));
  FTargetDP := LandrixXmlUtf8ToWide(LandrixGaebPhaseToDP(ATarget.Phase));
  FNamespace := LandrixGaebTargetNamespace(ATarget);
end;

destructor TLandrixGaebXmlWriteContext.Destroy;
begin
  inherited Destroy;
end;

procedure TLandrixGaebXmlWriteContext.Report(const ARuleId: string;
  ASeverity: TLandrixGaebSeverity; const AMessage: string);
begin
  if ASeverity >= gsError then
    Inc(FErrors)
  else if ASeverity = gsWarning then
    Inc(FWarnings);
  if FDiagnostics <> nil then
    FDiagnostics.AddAt(ARuleId, ASeverity, Path, 0, 0, -1, AMessage);
end;

procedure TLandrixGaebXmlWriteContext.Loss(const ARuleId, AMessage: string);
begin
  if FOptions.Mode = gwmBestEffort then
    Report(ARuleId, gsWarning, AMessage + '; left out')
  else
    Report(ARuleId, gsError, AMessage);
end;

function TLandrixGaebXmlWriteContext.Path: TLandrixGaebString;
var
  I: Integer;
  S: TLandrixXmlUtf8;
begin
  S := '';
  for I := 1 to FDepth do
    S := S + '/' + FFrames[I].Name + '[' + LandrixXmlStringToUtf8(IntToStr(FFrames[I].Index)) + ']';
  Result := LandrixXmlUtf8ToWide(S);
end;

procedure TLandrixGaebXmlWriteContext.Enter(const AName: TLandrixXmlUtf8);
var
  I, P: Integer;
begin
  { count AName among the children of the parent; an element has few
    distinct child names }
  P := FDepth;
  I := 0;
  while (I < FFrames[P].ChildCount) and (FFrames[P].ChildNames[I] <> AName) do
    Inc(I);
  if I = FFrames[P].ChildCount then
  begin
    if I = Integer(Length(FFrames[P].ChildNames)) then
    begin
      SetLength(FFrames[P].ChildNames, 2 * I + 4);
      SetLength(FFrames[P].ChildCounts, 2 * I + 4);
    end;
    FFrames[P].ChildNames[I] := AName;
    FFrames[P].ChildCounts[I] := 0;
    Inc(FFrames[P].ChildCount);
  end;
  Inc(FFrames[P].ChildCounts[I]);
  Inc(FDepth);
  if FDepth = Integer(Length(FFrames)) then
    SetLength(FFrames, 2 * FDepth);
  FFrames[FDepth].Name := AName;
  FFrames[FDepth].Index := FFrames[P].ChildCounts[I];
  FFrames[FDepth].ChildCount := 0;
end;

procedure TLandrixGaebXmlWriteContext.StartRoot(const AName: TLandrixXmlUtf8);
begin
  FWriter.StartElementNs(FNamespace, '', AName);
  Enter(AName);
end;

procedure TLandrixGaebXmlWriteContext.StartElement(const AName: TLandrixXmlUtf8; AMixed: Boolean);
begin
  FWriter.StartElement(AName, AMixed);
  Enter(AName);
end;

procedure TLandrixGaebXmlWriteContext.EndElement;
begin
  FWriter.EndElement;
  Dec(FDepth);
end;

function TLandrixGaebXmlWriteContext.Allowed(ASlot: Integer; const AName: TLandrixXmlUtf8;
  AAttribute: Boolean): Boolean;
begin
  Result := LandrixGaebXmlSlots[ASlot].Row <> LandrixGaebXmlSlotForbidden;
  if Result then
    Exit;
  if AAttribute then
    Loss('GAEB-WRT-001', 'attribute ' + LandrixXmlUtf8ToString(AName) + ' not allowed in the target')
  else
    Loss('GAEB-WRT-001', 'element ' + LandrixXmlUtf8ToString(AName) + ' not allowed in the target');
end;

function TLandrixGaebXmlWriteContext.ChildRow(ASlot: Integer): Integer;
begin
  Result := LandrixGaebXmlSlots[ASlot].Row;
end;

procedure TLandrixGaebXmlWriteContext.ValueText(ASlot: Integer; const AName: TLandrixXmlUtf8;
  const AValue: TLandrixGaebString);
begin
  if Allowed(ASlot, AName, False) then
    FWriter.ElementW(AName, AValue);
end;

procedure TLandrixGaebXmlWriteContext.ValueDecimal(ASlot: Integer; const AName: TLandrixXmlUtf8;
  const AValue: TLandrixGaebDecimal);
var
  S: TLandrixXmlUtf8;
  Digits: Integer;
begin
  if not Allowed(ASlot, AName, False) then
    Exit;
  Digits := LandrixGaebXmlSlots[ASlot].Fraction;
  if (FOptions.UPFracDig >= 0) and (FOptions.UPFracDig < Digits) and IsUnitPrice(AName) then
    Digits := FOptions.UPFracDig;
  if FOptions.PreserveScale or (Digits < 0) then
    S := AValue.Text
  else if not AValue.TryTextWithScale(Digits, S) then
  begin
    Loss('GAEB-WRT-002', 'element ' + LandrixXmlUtf8ToString(AName) + ' has more than ' +
      IntToStr(Digits) + ' fraction digits');
    Exit;
  end;
  FWriter.ElementUtf8(AName, S);
end;

procedure TLandrixGaebXmlWriteContext.ValueDecimalText(ASlot: Integer;
  const AName: TLandrixXmlUtf8; const AValue: TLandrixGaebDecimalText);
begin
  if Allowed(ASlot, AName, False) then
    FWriter.ElementUtf8(AName, AValue.Text);
end;

procedure TLandrixGaebXmlWriteContext.AttrText(ASlot: Integer; const AName: TLandrixXmlUtf8;
  const AValue: TLandrixGaebString);
begin
  if Allowed(ASlot, AName, True) then
    FWriter.AttributeW(AName, AValue);
end;

procedure TLandrixGaebXmlWriteContext.AttrDecimal(ASlot: Integer; const AName: TLandrixXmlUtf8;
  const AValue: TLandrixGaebDecimal);
var
  S: TLandrixXmlUtf8;
  Digits: Integer;
begin
  if not Allowed(ASlot, AName, True) then
    Exit;
  Digits := LandrixGaebXmlSlots[ASlot].Fraction;
  if FOptions.PreserveScale or (Digits < 0) then
    S := AValue.Text
  else if not AValue.TryTextWithScale(Digits, S) then
  begin
    Loss('GAEB-WRT-002', 'attribute ' + LandrixXmlUtf8ToString(AName) + ' has more than ' +
      IntToStr(Digits) + ' fraction digits');
    Exit;
  end;
  FWriter.AttributeUtf8(AName, S);
end;

procedure TLandrixGaebXmlWriteContext.AttrDecimalText(ASlot: Integer;
  const AName: TLandrixXmlUtf8; const AValue: TLandrixGaebDecimalText);
begin
  if Allowed(ASlot, AName, True) then
    FWriter.AttributeUtf8(AName, AValue.Text);
end;

procedure TLandrixGaebXmlWriteContext.ContentText(const AValue: TLandrixGaebString);
begin
  if AValue <> '' then
    FWriter.TextW(AValue);
end;

procedure TLandrixGaebXmlWriteContext.ContentDecimal(ASlot: Integer;
  const AValue: TLandrixGaebDecimal);
var
  S: TLandrixXmlUtf8;
  Digits: Integer;
begin
  if not AValue.HasValue then
    Exit;
  Digits := LandrixGaebXmlSlots[ASlot].Fraction;
  if FOptions.PreserveScale or (Digits < 0) then
    S := AValue.Text
  else if not AValue.TryTextWithScale(Digits, S) then
  begin
    Loss('GAEB-WRT-002', 'content has more than ' + IntToStr(Digits) + ' fraction digits');
    Exit;
  end;
  FWriter.TextUtf8(S);
end;

procedure TLandrixGaebXmlWriteContext.ContentDecimalText(const AValue: TLandrixGaebDecimalText);
begin
  if AValue.HasValue then
    FWriter.TextUtf8(AValue.Text);
end;

procedure TLandrixGaebXmlWriteContext.ContentUtf8(const AValue: TLandrixXmlUtf8);
begin
  if AValue <> '' then
    FWriter.TextUtf8(AValue);
end;

function TLandrixGaebXmlWriteContext.TargetVersion(const AModel: TLandrixGaebString): TLandrixGaebString;
begin
  Result := FTargetVersion;
  if (AModel <> '') and (AModel <> Result) then
    Report('GAEB-WRT-003', gsInformation, 'Version of the model replaced by the target');
end;

function TLandrixGaebXmlWriteContext.TargetVersDate(const AModel: TLandrixGaebString): TLandrixGaebString;
begin
  Result := FTargetVersDate;
  if (AModel <> '') and (AModel <> Result) then
    Report('GAEB-WRT-003', gsInformation, 'VersDate of the model replaced by the target');
end;

function TLandrixGaebXmlWriteContext.TargetDP(const AModel: TLandrixGaebString): TLandrixGaebString;
begin
  Result := FTargetDP;
  if (AModel <> '') and (AModel <> Result) then
    Report('GAEB-WRT-003', gsInformation, 'DP of the model replaced by the target');
end;

procedure TLandrixGaebXmlWriteContext.BadChild(const AName: TLandrixXmlUtf8);
begin
  if AName = '' then
    Loss('GAEB-WRT-004', 'text node in element-only content')
  else
    Loss('GAEB-WRT-004', 'child node ' + LandrixXmlUtf8ToString(AName) +
      ' does not fit its container');
end;

end.
