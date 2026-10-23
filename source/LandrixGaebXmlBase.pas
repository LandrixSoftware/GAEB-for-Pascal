{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Base classes of the generated GAEB DA XML syntax model
  (LandrixGaebXmlModel): the node every element class derives from, value
  and text nodes for ordered child lists, and the owning node list.

  Presence: an element counts as present if it was read, if Present was set,
  or if it is not empty (IsPresent). Property getters of the model create
  child objects on first access without marking them present, so reading a
  property never adds an element to the output; writers and checks use the
  generated HasX functions, which never create objects.

  Empty values: a simple value '' means "absent". An element or attribute
  that exists but is empty (<Name1/>, Name="") is kept as an empty mark on
  the object that owns it (MarkEmpty): the reader sets the marks, the writer
  writes marked empty values back, so empty mandatory elements survive a
  round trip without placeholders.

  DE: Basisklassen des generierten GAEB-DA-XML-Syntaxmodells
  (LandrixGaebXmlModel): der Knoten, von dem jede Elementklasse erbt, Wert-
  und Textknoten fuer geordnete Kinderlisten und die besitzende Knotenliste.

  Vorhandensein: Ein Element gilt als vorhanden, wenn es gelesen wurde, wenn
  Present gesetzt ist oder wenn es nicht leer ist (IsPresent). Die Getter
  des Modells legen Unterobjekte beim ersten Zugriff an, ohne sie als
  vorhanden zu markieren; das Lesen einer Eigenschaft fuegt der Ausgabe
  also nie ein Element hinzu. Schreiber und Pruefungen benutzen die
  generierten HasX-Funktionen, die nie Objekte anlegen.

  Leere Werte: Ein einfacher Wert '' bedeutet "nicht vorhanden". Ein
  Element oder Attribut, das vorhanden, aber leer ist (<Name1/>, Name=""),
  wird als Leer-Markierung am besitzenden Objekt gehalten (MarkEmpty): Der
  Leser setzt die Markierungen, der Schreiber schreibt markierte leere Werte
  zurueck, so dass leere Pflichtelemente einen Roundtrip ohne Platzhalter
  ueberstehen. }

{ API: internal. May change in any release before 1.0.
  DE: API: intern. Kann sich vor Version 1.0 in jeder Version aendern. }

unit LandrixGaebXmlBase;

{$I LandrixGaeb.inc}

interface

uses
  SysUtils,
  Classes,
  Contnrs,
  LandrixXmlBase,
  LandrixGaebTypes;

type
  { Base class of every element of the syntax model.
    DE: Basisklasse jedes Elements des Syntaxmodells. }
  TLandrixGaebXmlNode = class(TObject)
  private
    FEmptyMarks: TStringList;
  public
    { Local name of the element. Set by the reader and by the AddX helpers
      of ordered child lists; there it tells which element a node is (the
      same class can stand for several element names). For single fields
      and typed lists the writer takes the name from the field.
      DE: Lokaler Name des Elements. Gesetzt vom Leser und von den
      AddX-Helfern geordneter Kinderlisten; dort sagt er, welches Element
      ein Knoten ist (dieselbe Klasse kann fuer mehrere Elementnamen
      stehen). Bei Einzelfeldern und typisierten Listen nimmt der Schreiber
      den Namen aus dem Feld. }
    ElementName: TLandrixXmlUtf8;
    { True if the element was read or shall be written even when empty.
      DE: True, wenn das Element gelesen wurde oder auch leer geschrieben
      werden soll. }
    Present: Boolean;
    destructor Destroy; override;
    { True if the element has no content, no attribute value and no empty
      mark.
      DE: True, wenn das Element weder Inhalt noch Attributwert noch
      Leer-Markierung hat. }
    function IsEmpty: Boolean; virtual;
    { Marks the simple child element AName (or the attribute '@' + name) of
      this element as present but empty; it is written as <AName/> while
      its value is ''.
      DE: Markiert das einfache Kindelement AName (oder das Attribut '@' +
      Name) dieses Elements als vorhanden, aber leer; es wird als <AName/>
      geschrieben, solange sein Wert '' ist. }
    procedure MarkEmpty(const AName: TLandrixXmlUtf8);
    { True if AName carries an empty mark. DE: True, wenn AName eine
      Leer-Markierung traegt. }
    function IsMarkedEmpty(const AName: TLandrixXmlUtf8): Boolean;
    { Removes all empty marks. DE: Entfernt alle Leer-Markierungen. }
    procedure ClearEmptyMarks;
    { Present or not IsEmpty: the element is written.
      DE: Present oder nicht IsEmpty: das Element wird geschrieben. }
    function IsPresent: Boolean;
    { Removes all content and resets Present; ElementName stays.
      DE: Entfernt allen Inhalt und setzt Present zurueck; ElementName
      bleibt. }
    procedure Clear; virtual;
  end;

  { Element of a simple type inside an ordered child list (for example br,
    page, attachment). Value '' means an empty element.
    DE: Element eines einfachen Typs in einer geordneten Kinderliste (zum
    Beispiel br, page, attachment). Value '' bedeutet ein leeres Element. }
  TLandrixGaebXmlValueNode = class(TLandrixGaebXmlNode)
  public
    { Text content. DE: Textinhalt. }
    Value: TLandrixGaebString;
    function IsEmpty: Boolean; override;
    procedure Clear; override;
  end;

  { Character data found directly in a container whose content model allows
    elements only (for example text directly in p). The reader keeps it and
    reports it; it is never silently moved into another element. ElementName
    is ''.
    DE: Zeichendaten direkt in einem Container, dessen Inhaltsmodell nur
    Elemente erlaubt (zum Beispiel Text direkt in p). Der Leser behaelt sie
    und meldet sie; sie werden nie stillschweigend in ein anderes Element
    verschoben. ElementName ist ''. }
  TLandrixGaebXmlTextNode = class(TLandrixGaebXmlNode)
  public
    { The character data. DE: Die Zeichendaten. }
    Text: TLandrixGaebString;
    function IsEmpty: Boolean; override;
    procedure Clear; override;
  end;

  { Ordered list of child nodes; owns its items.
    DE: Geordnete Liste von Kindknoten; besitzt ihre Eintraege. }
  TLandrixGaebXmlNodeList = class(TObjectList)
  protected
    function GetItem(Index: TLandrixGaebListIndex): TLandrixGaebXmlNode;
  public
    property Items[Index: TLandrixGaebListIndex]: TLandrixGaebXmlNode read GetItem; default;
    { Appends a node (the list takes ownership) and returns it.
      DE: Haengt einen Knoten an (die Liste uebernimmt ihn) und liefert
      ihn. }
    function AddNode(ANode: TLandrixGaebXmlNode): TLandrixGaebXmlNode;
    { Appends a present value node with the element name and value (also
      when the value is empty, for example br) and returns it.
      DE: Haengt einen vorhandenen Wertknoten mit Elementname und Wert an
      (auch bei leerem Wert, zum Beispiel br) und liefert ihn. }
    function AddValue(const AElementName: TLandrixXmlUtf8;
      const AValue: TLandrixGaebString): TLandrixGaebXmlValueNode;
    { True if no item is present (see TLandrixGaebXmlNode.IsPresent).
      DE: True, wenn kein Eintrag vorhanden ist (siehe
      TLandrixGaebXmlNode.IsPresent). }
    function IsEmpty: Boolean;
  end;

implementation

{ TLandrixGaebXmlNode }

destructor TLandrixGaebXmlNode.Destroy;
begin
  FEmptyMarks.Free;
  inherited Destroy;
end;

function TLandrixGaebXmlNode.IsEmpty: Boolean;
begin
  Result := (FEmptyMarks = nil) or (FEmptyMarks.Count = 0);
end;

{ Exact (ordinal) search; TStringList.IndexOf compares locale-dependent. }
function FindMark(AList: TStringList; const AName: string): Integer;
begin
  Result := AList.Count - 1;
  while (Result >= 0) and (AList[Result] <> AName) do
    Dec(Result);
end;

procedure TLandrixGaebXmlNode.MarkEmpty(const AName: TLandrixXmlUtf8);
var
  S: string;
begin
  S := LandrixXmlUtf8ToString(AName);
  if FEmptyMarks = nil then
    FEmptyMarks := TStringList.Create;
  if FindMark(FEmptyMarks, S) < 0 then
    FEmptyMarks.Add(S);
end;

function TLandrixGaebXmlNode.IsMarkedEmpty(const AName: TLandrixXmlUtf8): Boolean;
begin
  Result := (FEmptyMarks <> nil) and (FindMark(FEmptyMarks, LandrixXmlUtf8ToString(AName)) >= 0);
end;

procedure TLandrixGaebXmlNode.ClearEmptyMarks;
begin
  FreeAndNil(FEmptyMarks);
end;

function TLandrixGaebXmlNode.IsPresent: Boolean;
begin
  Result := Present or not IsEmpty;
end;

procedure TLandrixGaebXmlNode.Clear;
begin
  Present := False;
  ClearEmptyMarks;
end;

{ TLandrixGaebXmlValueNode }

function TLandrixGaebXmlValueNode.IsEmpty: Boolean;
begin
  Result := Value = '';
end;

procedure TLandrixGaebXmlValueNode.Clear;
begin
  inherited Clear;
  Value := '';
end;

{ TLandrixGaebXmlTextNode }

function TLandrixGaebXmlTextNode.IsEmpty: Boolean;
begin
  Result := Text = '';
end;

procedure TLandrixGaebXmlTextNode.Clear;
begin
  inherited Clear;
  Text := '';
end;

{ TLandrixGaebXmlNodeList }

function TLandrixGaebXmlNodeList.GetItem(Index: TLandrixGaebListIndex): TLandrixGaebXmlNode;
begin
  Result := TLandrixGaebXmlNode(inherited Items[Index]);
end;

function TLandrixGaebXmlNodeList.AddNode(ANode: TLandrixGaebXmlNode): TLandrixGaebXmlNode;
begin
  inherited Add(ANode);
  Result := ANode;
end;

function TLandrixGaebXmlNodeList.AddValue(const AElementName: TLandrixXmlUtf8;
  const AValue: TLandrixGaebString): TLandrixGaebXmlValueNode;
begin
  Result := TLandrixGaebXmlValueNode.Create;
  Result.ElementName := AElementName;
  Result.Value := AValue;
  Result.Present := True;
  inherited Add(Result);
end;

function TLandrixGaebXmlNodeList.IsEmpty: Boolean;
var
  I: TLandrixGaebListIndex;
begin
  Result := False;
  for I := 0 to Count - 1 do
    if Items[I].IsPresent then
      Exit;
  Result := True;
end;

end.
