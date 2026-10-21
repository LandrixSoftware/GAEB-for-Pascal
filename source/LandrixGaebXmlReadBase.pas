{
  GAEB-for-pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Reading context of the generated GAEB DA XML reader
  (LandrixGaebXmlReader): wraps the pull reader of LandrixXml and reports
  what does not fit the schema without stopping. Reading is tolerant:
  unknown elements, elements of other namespaces, wrong order, repeated
  elements, invalid values and text in element-only content become
  diagnostics with element path, line and column; only XML that is not
  well-formed stops reading (ELandrixXmlError with position).

  Diagnostics (rule identifiers):
    GAEB-XML-001 error    unknown element (skipped)
    GAEB-XML-002 warning  elements or attributes of another namespace
                          (skipped; reported once per namespace; xmlns,
                          xml and xsi attributes are not reported)
    GAEB-XML-003 error    invalid value (for example a decimal that is no
                          xs:decimal or has more than 18 digits)
    GAEB-XML-004 error    element repeated where the schema allows one
                          (the repetition is skipped)
    GAEB-XML-005 error    element out of schema order (read anyway)
    GAEB-XML-006 error    unknown attribute (ignored)
    GAEB-XML-007 error    text in element-only content (kept as text node
                          in ordered child lists, otherwise dropped)
    GAEB-XML-008 error    element inside a simple element (skipped)

  A repeated group (for example CnstSite with its NotifSite) is split at
  its members only; a group that lacks its mandatory member is not reported
  here but by the check of the content model.

  DE: Lesekontext des generierten GAEB-DA-XML-Lesers
  (LandrixGaebXmlReader): kapselt den Pull-Reader von LandrixXml und meldet,
  was nicht zum Schema passt, ohne abzubrechen. Lesen ist tolerant:
  unbekannte Elemente, Elemente fremder Namespaces, falsche Reihenfolge,
  wiederholte Elemente, ungueltige Werte und Text in reinem Elementinhalt
  werden Meldungen mit Elementpfad, Zeile und Spalte; nur nicht
  wohlgeformtes XML bricht ab (ELandrixXmlError mit Position). Die
  Regelkennungen oben gelten unveraendert; die Texte sind englisch und
  enthalten keinen Dateiinhalt. }

{ API: internal. May change in any release before 1.0.
  DE: API: intern. Kann sich vor Version 1.0 in jeder Version aendern. }

unit LandrixGaebXmlReadBase;

{$I LandrixGaeb.inc}

interface

uses
  SysUtils,
  Classes,
  LandrixXmlBase,
  LandrixXmlReader,
  LandrixGaebTypes,
  LandrixGaebDiagnostics,
  LandrixGaebXmlBase;

type
  { State of one read: the pull reader, the expected namespace and the
    diagnostics. Used by the generated reader only.
    DE: Zustand eines Lesevorgangs: Pull-Reader, erwarteter Namespace und
    Meldungen. Nur vom generierten Leser benutzt. }
  TLandrixGaebXmlReadContext = class(TObject)
  private
    FReader: TLandrixXmlReader;
    FNamespace: TLandrixXmlUtf8;
    FDiagnostics: TLandrixGaebDiagnostics;
    FForeign: TStringList;
    procedure Report(const ARuleId: string; ASeverity: TLandrixGaebSeverity;
      const AMessage: string);
    function NamespaceIsGaeb(const ASpan: TLandrixXmlSpan): Boolean;
    procedure ReportForeign(const ANamespace: TLandrixXmlUtf8);
    procedure CheckNoAttributes;
    function ReadText: TLandrixXmlUtf8;
    procedure ReadDecimal(const AText: TLandrixXmlUtf8; var AValue: TLandrixGaebDecimal;
      const APath: TLandrixGaebString; ALine, AColumn: Integer; AOffset: Int64);
    procedure ReadDecimalText(const AText: TLandrixXmlUtf8; var AValue: TLandrixGaebDecimalText;
      const APath: TLandrixGaebString; ALine, AColumn: Integer; AOffset: Int64);
  public
    { AReader stands before or on the root element; ADiagnostics may be nil.
      DE: AReader steht vor oder auf dem Wurzelelement; ADiagnostics darf
      nil sein. }
    constructor Create(AReader: TLandrixXmlReader; const ANamespace: TLandrixXmlUtf8;
      ADiagnostics: TLandrixGaebDiagnostics);
    destructor Destroy; override;
    { Moves to the root start element; False if there is none.
      DE: Geht zum Start-Tag der Wurzel; False, wenn es keines gibt. }
    function MoveToRoot: Boolean;
    { Marks ANode as read: Present, ElementName.
      DE: Markiert ANode als gelesen: Present, ElementName. }
    procedure Enter(ANode: TLandrixGaebXmlNode);
    { Next token inside the element of depth ADepth; False on its end tag
      (or for an empty element).
      DE: Naechstes Token innerhalb des Elements der Tiefe ADepth; False
      bei dessen End-Tag (oder bei einem leeren Element). }
    function Next(ADepth: Integer): Boolean;
    { True if the current start element is in the GAEB namespace; otherwise
      it is reported (once per namespace) and skipped.
      DE: True, wenn das aktuelle Start-Element im GAEB-Namespace liegt;
      sonst wird es gemeldet (einmal je Namespace) und uebersprungen. }
    function IsGaeb: Boolean;
    { True if the local name of the current element is AName.
      DE: True, wenn der lokale Name des aktuellen Elements AName ist. }
    function NameIs(const AName: TLandrixXmlUtf8): Boolean;
    { Reports an unknown element and skips it. DE: Meldet ein unbekanntes
      Element und ueberspringt es. }
    procedure UnknownElement;
    { Checks the schema order: AIndex is the position of the element in its
      class, ASingle tells that it may occur once, AHave that it was already
      read. False for a repetition of a single element (also out of order),
      which is reported and skipped.
      DE: Prueft die Schemareihenfolge: AIndex ist die Position des
      Elements in seiner Klasse, ASingle sagt, dass es einmal vorkommen
      darf, AHave, dass es schon gelesen wurde. False bei der Wiederholung
      eines Einzelelements (auch ausserhalb der Reihenfolge); sie wird
      gemeldet und uebersprungen. }
    function Order(var ALast: Integer; AIndex: Integer; ASingle, AHave: Boolean): Boolean;
    { True if a member of a repeated group starts a new group.
      DE: True, wenn ein Glied einer wiederholten Gruppe eine neue Gruppe
      beginnt. }
    function NewGroup(ALast, AIndex: Integer; ASingle: Boolean): Boolean;
    { Text content of the current element of a simple type, read up to its
      end tag; attributes of it are reported (a simple type has none).
      DE: Textinhalt des aktuellen Elements eines einfachen Typs, gelesen
      bis zu seinem End-Tag; seine Attribute werden gemeldet (ein einfacher
      Typ hat keine). }
    function ElementText: TLandrixGaebString;
    { Text content as UTF-8. DE: Textinhalt als UTF-8. }
    function ElementTextUtf8: TLandrixXmlUtf8;
    { Reads a bounded decimal element; invalid values are reported.
      DE: Liest ein begrenztes Dezimalelement; ungueltige Werte werden
      gemeldet. }
    procedure ElementDecimal(var AValue: TLandrixGaebDecimal);
    { Reads an unbounded decimal element. DE: Liest ein unbegrenztes
      Dezimalelement. }
    procedure ElementDecimalText(var AValue: TLandrixGaebDecimalText);
    { Text content of an element with simple content and attributes (the
      attributes were read by the caller).
      DE: Textinhalt eines Elements mit einfachem Inhalt und Attributen
      (die Attribute hat der Aufrufer gelesen). }
    function ContentText: TLandrixGaebString;
    { Content as UTF-8. DE: Inhalt als UTF-8. }
    function ContentTextUtf8: TLandrixXmlUtf8;
    { Content as bounded decimal. DE: Inhalt als begrenzte Dezimalzahl. }
    procedure ContentDecimal(var AValue: TLandrixGaebDecimal);
    { Content as unbounded decimal. DE: Inhalt als unbegrenzte
      Dezimalzahl. }
    procedure ContentDecimalText(var AValue: TLandrixGaebDecimalText);
    { True if attribute AIndex has no namespace. Namespace declarations and
      xml/xsi attributes are no data; attributes of other namespaces are
      reported once per namespace (GAEB-XML-002).
      DE: True, wenn Attribut AIndex keinen Namespace hat.
      Namespace-Deklarationen und xml-/xsi-Attribute sind keine Daten;
      Attribute anderer Namespaces werden einmal je Namespace gemeldet
      (GAEB-XML-002). }
    function IsPlainAttribute(AIndex: Integer): Boolean;
    { True if attribute AIndex has the local name AName.
      DE: True, wenn Attribut AIndex den lokalen Namen AName hat. }
    function AttributeIs(AIndex: Integer; const AName: TLandrixXmlUtf8): Boolean;
    { Value of attribute AIndex. DE: Wert von Attribut AIndex. }
    function AttributeText(AIndex: Integer): TLandrixGaebString;
    { Bounded decimal attribute. DE: Begrenztes Dezimalattribut. }
    procedure AttributeDecimal(AIndex: Integer; var AValue: TLandrixGaebDecimal);
    { Unbounded decimal attribute. DE: Unbegrenztes Dezimalattribut. }
    procedure AttributeDecimalText(AIndex: Integer; var AValue: TLandrixGaebDecimalText);
    { Reports an unknown attribute. DE: Meldet ein unbekanntes Attribut. }
    procedure UnknownAttribute(AIndex: Integer);
    { Handles character data in element-only content: whitespace is
      ignored, other text is reported and, if AChildren is not nil, kept as
      text node.
      DE: Behandelt Zeichendaten in reinem Elementinhalt: Leerraum wird
      ignoriert, anderer Text gemeldet und, wenn AChildren nicht nil ist,
      als Textknoten behalten. }
    procedure TextInElementContent(AChildren: TLandrixGaebXmlNodeList);
    { The pull reader. DE: Der Pull-Reader. }
    property Reader: TLandrixXmlReader read FReader;
  end;

implementation

const
  NamespaceXmlns = 'http://www.w3.org/2000/xmlns/';
  NamespaceXml = 'http://www.w3.org/XML/1998/namespace';
  NamespaceXsi = 'http://www.w3.org/2001/XMLSchema-instance';

{ TLandrixGaebXmlReadContext }

constructor TLandrixGaebXmlReadContext.Create(AReader: TLandrixXmlReader;
  const ANamespace: TLandrixXmlUtf8; ADiagnostics: TLandrixGaebDiagnostics);
begin
  inherited Create;
  FReader := AReader;
  FNamespace := ANamespace;
  FDiagnostics := ADiagnostics;
  FForeign := TStringList.Create;
  FForeign.Sorted := True;
end;

destructor TLandrixGaebXmlReadContext.Destroy;
begin
  FForeign.Free;
  inherited Destroy;
end;

procedure TLandrixGaebXmlReadContext.Report(const ARuleId: string;
  ASeverity: TLandrixGaebSeverity; const AMessage: string);
begin
  if FDiagnostics <> nil then
    FDiagnostics.AddAt(ARuleId, ASeverity, FReader.ElementPathW, FReader.Line,
      FReader.Column, FReader.Offset, AMessage);
end;

function TLandrixGaebXmlReadContext.NamespaceIsGaeb(const ASpan: TLandrixXmlSpan): Boolean;
begin
  Result := LandrixXmlSpanEquals(ASpan, FNamespace);
end;

function TLandrixGaebXmlReadContext.MoveToRoot: Boolean;
begin
  Result := FReader.TokenType = xttStartElement;
  while not Result and FReader.Read do
    Result := FReader.TokenType = xttStartElement;
end;

procedure TLandrixGaebXmlReadContext.Enter(ANode: TLandrixGaebXmlNode);
begin
  ANode.Present := True;
  ANode.ElementName := FReader.LocalNameUtf8;
end;

function TLandrixGaebXmlReadContext.Next(ADepth: Integer): Boolean;
begin
  Result := FReader.Read and
    not ((FReader.TokenType = xttEndElement) and (FReader.Depth = ADepth));
end;

procedure TLandrixGaebXmlReadContext.ReportForeign(const ANamespace: TLandrixXmlUtf8);
var
  Ns: string;
begin
  Ns := LandrixXmlUtf8ToString(ANamespace);
  if FForeign.IndexOf(Ns) >= 0 then
    Exit;
  FForeign.Add(Ns);
  if Ns = '' then
    Report('GAEB-XML-002', gsWarning, 'elements without namespace skipped')
  else
    Report('GAEB-XML-002', gsWarning, 'elements or attributes of namespace ' + Ns + ' skipped');
end;

function TLandrixGaebXmlReadContext.IsGaeb: Boolean;
begin
  Result := NamespaceIsGaeb(FReader.NamespaceUriSpan);
  if Result then
    Exit;
  ReportForeign(FReader.NamespaceUriUtf8);
  FReader.Skip;
end;

function TLandrixGaebXmlReadContext.NameIs(const AName: TLandrixXmlUtf8): Boolean;
begin
  Result := LandrixXmlSpanEquals(FReader.LocalNameSpan, AName);
end;

procedure TLandrixGaebXmlReadContext.UnknownElement;
begin
  Report('GAEB-XML-001', gsError, 'unknown element ' +
    LandrixXmlUtf8ToString(FReader.LocalNameUtf8) + ' skipped');
  FReader.Skip;
end;

function TLandrixGaebXmlReadContext.Order(var ALast: Integer; AIndex: Integer;
  ASingle, AHave: Boolean): Boolean;
begin
  Result := True;
  if ASingle and ((AIndex = ALast) or AHave) then
  begin
    Report('GAEB-XML-004', gsError, 'element ' +
      LandrixXmlUtf8ToString(FReader.LocalNameUtf8) + ' repeated; repetition skipped');
    FReader.Skip;
    Result := False;
  end
  else if AIndex < ALast then
    Report('GAEB-XML-005', gsError, 'element ' +
      LandrixXmlUtf8ToString(FReader.LocalNameUtf8) + ' out of schema order')
  else
    ALast := AIndex;
end;

function TLandrixGaebXmlReadContext.NewGroup(ALast, AIndex: Integer; ASingle: Boolean): Boolean;
begin
  Result := (AIndex < ALast) or ((AIndex = ALast) and ASingle);
end;

procedure TLandrixGaebXmlReadContext.CheckNoAttributes;
var
  I: Integer;
begin
  for I := 0 to FReader.AttributeCount - 1 do
    if IsPlainAttribute(I) then
      UnknownAttribute(I);
end;

function TLandrixGaebXmlReadContext.ReadText: TLandrixXmlUtf8;
var
  D: Integer;
begin
  Result := '';
  D := FReader.Depth;
  while Next(D) do
    case FReader.TokenType of
      xttText, xttCData:
        Result := Result + FReader.ValueUtf8;
      xttStartElement:
        begin
          Report('GAEB-XML-008', gsError, 'element ' +
            LandrixXmlUtf8ToString(FReader.LocalNameUtf8) + ' inside a simple element skipped');
          FReader.Skip;
        end;
    else
      ;
    end;
end;

function TLandrixGaebXmlReadContext.ElementTextUtf8: TLandrixXmlUtf8;
begin
  CheckNoAttributes;
  Result := ReadText;
end;

function TLandrixGaebXmlReadContext.ElementText: TLandrixGaebString;
begin
  Result := LandrixXmlUtf8ToWide(ElementTextUtf8);
end;

function TLandrixGaebXmlReadContext.ContentTextUtf8: TLandrixXmlUtf8;
begin
  Result := ReadText;
end;

function TLandrixGaebXmlReadContext.ContentText: TLandrixGaebString;
begin
  Result := LandrixXmlUtf8ToWide(ReadText);
end;

procedure TLandrixGaebXmlReadContext.ReadDecimal(const AText: TLandrixXmlUtf8;
  var AValue: TLandrixGaebDecimal; const APath: TLandrixGaebString; ALine, AColumn: Integer;
  AOffset: Int64);
begin
  if not AValue.TrySetText(AText) and (FDiagnostics <> nil) then
    FDiagnostics.AddAt('GAEB-XML-003', gsError, APath, ALine, AColumn, AOffset,
      'invalid decimal (not xs:decimal or more than 18 digits); value dropped');
end;

procedure TLandrixGaebXmlReadContext.ReadDecimalText(const AText: TLandrixXmlUtf8;
  var AValue: TLandrixGaebDecimalText; const APath: TLandrixGaebString; ALine, AColumn: Integer;
  AOffset: Int64);
begin
  if not AValue.TrySetText(AText) and (FDiagnostics <> nil) then
    FDiagnostics.AddAt('GAEB-XML-003', gsError, APath, ALine, AColumn, AOffset,
      'invalid decimal (not xs:decimal); value dropped');
end;

procedure TLandrixGaebXmlReadContext.ElementDecimal(var AValue: TLandrixGaebDecimal);
var
  Line, Column: Integer;
  Offset: Int64;
  Path: TLandrixGaebString;
begin
  Line := FReader.Line;
  Column := FReader.Column;
  Offset := FReader.Offset;
  Path := FReader.ElementPathW;
  ReadDecimal(ElementTextUtf8, AValue, Path, Line, Column, Offset);
end;

procedure TLandrixGaebXmlReadContext.ElementDecimalText(var AValue: TLandrixGaebDecimalText);
var
  Line, Column: Integer;
  Offset: Int64;
  Path: TLandrixGaebString;
begin
  Line := FReader.Line;
  Column := FReader.Column;
  Offset := FReader.Offset;
  Path := FReader.ElementPathW;
  ReadDecimalText(ElementTextUtf8, AValue, Path, Line, Column, Offset);
end;

procedure TLandrixGaebXmlReadContext.ContentDecimal(var AValue: TLandrixGaebDecimal);
var
  Line, Column: Integer;
  Offset: Int64;
  Path: TLandrixGaebString;
begin
  Line := FReader.Line;
  Column := FReader.Column;
  Offset := FReader.Offset;
  Path := FReader.ElementPathW;
  ReadDecimal(ContentTextUtf8, AValue, Path, Line, Column, Offset);
end;

procedure TLandrixGaebXmlReadContext.ContentDecimalText(var AValue: TLandrixGaebDecimalText);
var
  Line, Column: Integer;
  Offset: Int64;
  Path: TLandrixGaebString;
begin
  Line := FReader.Line;
  Column := FReader.Column;
  Offset := FReader.Offset;
  Path := FReader.ElementPathW;
  ReadDecimalText(ContentTextUtf8, AValue, Path, Line, Column, Offset);
end;

function TLandrixGaebXmlReadContext.IsPlainAttribute(AIndex: Integer): Boolean;
var
  Ns: TLandrixXmlUtf8;
begin
  Result := FReader.AttributeNamespaceUriSpan(AIndex).Len = 0;
  if Result then
    Exit;
  Ns := FReader.AttributeNamespaceUriUtf8(AIndex);
  if (Ns <> NamespaceXmlns) and (Ns <> NamespaceXml) and (Ns <> NamespaceXsi) then
    ReportForeign(Ns);
end;

function TLandrixGaebXmlReadContext.AttributeIs(AIndex: Integer;
  const AName: TLandrixXmlUtf8): Boolean;
begin
  Result := LandrixXmlSpanEquals(FReader.AttributeLocalNameSpan(AIndex), AName);
end;

function TLandrixGaebXmlReadContext.AttributeText(AIndex: Integer): TLandrixGaebString;
begin
  Result := FReader.AttributeValueW(AIndex);
end;

procedure TLandrixGaebXmlReadContext.AttributeDecimal(AIndex: Integer;
  var AValue: TLandrixGaebDecimal);
begin
  if not AValue.TrySetText(FReader.AttributeValueUtf8(AIndex)) then
    Report('GAEB-XML-003', gsError, 'invalid decimal in attribute ' +
      LandrixXmlUtf8ToString(FReader.AttributeLocalNameUtf8(AIndex)) + '; value dropped');
end;

procedure TLandrixGaebXmlReadContext.AttributeDecimalText(AIndex: Integer;
  var AValue: TLandrixGaebDecimalText);
begin
  if not AValue.TrySetText(FReader.AttributeValueUtf8(AIndex)) then
    Report('GAEB-XML-003', gsError, 'invalid decimal in attribute ' +
      LandrixXmlUtf8ToString(FReader.AttributeLocalNameUtf8(AIndex)) + '; value dropped');
end;

procedure TLandrixGaebXmlReadContext.UnknownAttribute(AIndex: Integer);
begin
  Report('GAEB-XML-006', gsError, 'unknown attribute ' +
    LandrixXmlUtf8ToString(FReader.AttributeLocalNameUtf8(AIndex)) + ' ignored');
end;

procedure TLandrixGaebXmlReadContext.TextInElementContent(AChildren: TLandrixGaebXmlNodeList);
var
  Node: TLandrixGaebXmlTextNode;
begin
  if FReader.IsWhitespace then
    Exit;
  if AChildren <> nil then
  begin
    Node := TLandrixGaebXmlTextNode.Create;
    Node.Present := True;
    Node.Text := FReader.ValueW;
    AChildren.AddNode(Node);
    Report('GAEB-XML-007', gsError, 'text in element-only content kept as text node');
  end
  else
    Report('GAEB-XML-007', gsError, 'text in element-only content dropped');
end;

end.
