{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ The bill of quantities of a syntax model as a flat list of nodes in
  document order (categories, items, markup items, execution
  descriptions, remarks) with their ordinal number (OZ), the OZ order and key, and
  the counting rule of the totals. Shared by the business rules
  (LandrixGaebRules) and the business facade, so that uniqueness, order,
  pair matching and totals agree everywhere.

  DE: Das Leistungsverzeichnis eines Syntaxmodells als flache Liste von
  Knoten in Dokumentreihenfolge (Bereiche, Positionen, Zuschlagspositionen,
  Ausfuehrungsbeschreibungen, Bemerkungen) mit Ordnungszahl (OZ), OZ-Reihenfolge und
  -Schluessel sowie der Zaehlregel der Summen. Gemeinsam genutzt von den
  Geschaeftsregeln (LandrixGaebRules) und der fachlichen Fassade, damit
  Eindeutigkeit, Reihenfolge, Paarzuordnung und Summen ueberall
  uebereinstimmen. }

{ API: internal. May change in any release, also after 1.0.
  DE: API: intern. Kann sich in jeder Version aendern, auch nach 1.0. }

unit LandrixGaebBoQTree;

{$I LandrixGaeb.inc}

interface

uses
  SysUtils,
  Classes,
  Contnrs,
  LandrixXmlBase,
  LandrixXmlDecimal,
  LandrixGaebTypes,
  LandrixGaebXmlBase,
  LandrixGaebXmlModel;

const
  { Kinds of a node. DE: Arten eines Knotens. }
  LandrixGaebTreeRoot = 0;
  LandrixGaebTreeCtgy = 1;
  LandrixGaebTreeItem = 2;
  LandrixGaebTreeMarkup = 3;
  LandrixGaebTreePerf = 4;
  LandrixGaebTreeRemark = 5;

type
  { A category, item, markup item or execution description in document
    order, with the parts of its OZ (RNoPart of every enclosing category
    and its own), the index and the key built from them. Sum and SumKnown
    are working fields of total computations.
    DE: Ein Bereich, eine Position, Zuschlagsposition oder
    Ausfuehrungsbeschreibung in Dokumentreihenfolge mit den Teilen der OZ
    (RNoPart aller umgebenden Bereiche und der eigene), dem Index und dem
    daraus gebildeten Schluessel. Sum und SumKnown sind Arbeitsfelder von
    Summenberechnungen. }
  TLandrixGaebTreeNode = class(TObject)
  public
    { The node of the syntax model (not owned; valid as long as the
      document). DE: Der Knoten des Syntaxmodells (nicht im Besitz; gueltig,
      solange das Dokument besteht). }
    Node: TLandrixGaebXmlNode;
    { LandrixGaebTreeRoot to LandrixGaebTreeRemark. DE: LandrixGaebTreeRoot
      bis LandrixGaebTreeRemark. }
    Kind: Integer;
    { Enclosing category, the root at top level, nil for the root.
      DE: Umgebender Bereich, auf oberster Ebene die Wurzel, nil fuer die
      Wurzel. }
    Parent: TLandrixGaebTreeNode;
    { RNoPart of every enclosing category and the own one (none for
      execution descriptions and remarks). DE: RNoPart aller umgebenden
      Bereiche und der eigene (keine bei Ausfuehrungsbeschreibungen und
      Bemerkungen). }
    Parts: array of TLandrixGaebString;
    { RNoIndex of an item. DE: RNoIndex einer Position. }
    Index: TLandrixGaebString;
    { Parts by LandrixGaebKeyPart joined with '.', '#' and the index.
      DE: Teile nach LandrixGaebKeyPart mit '.' verbunden, '#' und der
      Index. }
    Key: TLandrixGaebString;
    { Path of the element for diagnostics. DE: Pfad des Elements fuer
      Meldungen. }
    Path: TLandrixXmlUtf8;
    { Position in document order, from 1. DE: Position in
      Dokumentreihenfolge, ab 1. }
    Order: Integer;
    { Working fields of total computations: sum of the counting children;
      SumKnown is False if a child has no amount or makes the sum unknown.
      DE: Arbeitsfelder von Summenberechnungen: Summe der zaehlenden
      Kinder; SumKnown ist False, wenn ein Kind keinen Betrag hat oder die
      Summe unbekannt macht. }
    Sum: TLandrixXmlDecimal;
    SumKnown: Boolean;
  end;

  { Keys with their nodes (not owned), sorted by key and order (string
    comparison of the compiler; keys are ASCII).
    DE: Schluessel mit ihren Knoten, sortiert nach Schluessel und
    Reihenfolge (Knoten nicht im Besitz; Zeichenkettenvergleich des
    Compilers; Schluessel sind ASCII). }
  TLandrixGaebKeyIndex = class(TObject)
  private
    FKeys: array of TLandrixGaebString;
    FNodes: array of TLandrixGaebTreeNode;
    FCount: Integer;
    function Less(I, J: Integer): Boolean;
    procedure Swap(I, J: Integer);
    procedure QuickSort(L, R: Integer);
  public
    { Adds a key; Sort before Find. DE: Fuegt einen Schluessel hinzu; vor
      Find sortieren. }
    procedure Add(const AKey: TLandrixGaebString; ANode: TLandrixGaebTreeNode);
    { Sorts by key, equal keys in document order. DE: Sortiert nach
      Schluessel, gleiche Schluessel in Dokumentreihenfolge. }
    procedure Sort;
    { First node with AKey, nil if none (after Sort). DE: Erster Knoten mit
      AKey, nil, wenn keiner (nach Sort). }
    function Find(const AKey: TLandrixGaebString): TLandrixGaebTreeNode;
    { Key and node at position I. DE: Schluessel und Knoten an Position I. }
    function Key(I: Integer): TLandrixGaebString;
    function Node(I: Integer): TLandrixGaebTreeNode;
    { Number of keys. DE: Anzahl der Schluessel. }
    property Count: Integer read FCount;
  end;

  { The nodes of the bill of quantities of a document (Award/BoQ/BoQBody),
    collected on creation; the document is not changed and must outlive
    the tree. Root stands for the bill itself (no OZ parts). Without Award
    or BoQ the list is empty.
    DE: Die Knoten des Leistungsverzeichnisses eines Dokuments
    (Award/BoQ/BoQBody), beim Anlegen gesammelt; das Dokument wird nicht
    veraendert und muss den Baum ueberleben. Root steht fuer das LV selbst
    (ohne OZ-Teile). Ohne Award oder BoQ ist die Liste leer. }
  TLandrixGaebTree = class(TObject)
  private
    FNodes: TObjectList;
    FRoot: TLandrixGaebTreeNode;
    FInfoPath: TLandrixXmlUtf8;
    function AddNode(ANode: TLandrixGaebXmlNode; AKind: Integer; AParent: TLandrixGaebTreeNode;
      const APath: TLandrixXmlUtf8; const APart, AIndex: TLandrixGaebString): TLandrixGaebTreeNode;
    procedure WalkBody(ABody: TLandrixGaebXmlBoQBody; AParent: TLandrixGaebTreeNode; const APath: TLandrixXmlUtf8);
    procedure WalkItems(AList: TLandrixGaebXmlItemlist; AParent: TLandrixGaebTreeNode;
      const APath: TLandrixXmlUtf8);
  public
    { Collects the nodes of ADocument. DE: Sammelt die Knoten von ADocument. }
    constructor Create(ADocument: TLandrixGaebXmlGAEB);
    { Frees the nodes and the root, not the document. DE: Gibt die Knoten
      und die Wurzel frei, nicht das Dokument. }
    destructor Destroy; override;
    { The nodes in document order (TLandrixGaebTreeNode, owned).
      DE: Die Knoten in Dokumentreihenfolge (TLandrixGaebTreeNode, im
      Besitz). }
    property Nodes: TObjectList read FNodes;
    { The bill itself. DE: Das LV selbst. }
    property Root: TLandrixGaebTreeNode read FRoot;
    { Path of BoQInfo. DE: Pfad von BoQInfo. }
    property InfoPath: TLandrixXmlUtf8 read FInfoPath;
  end;

{ True if S holds digits only and is not empty.
  DE: True, wenn S nur aus Ziffern besteht und nicht leer ist. }
function LandrixGaebIsDigits(const S: TLandrixGaebString): Boolean;

{ Digits without leading zeros ('' for zero).
  DE: Ziffern ohne fuehrende Nullen ('' fuer null). }
function LandrixGaebStripZeros(const S: TLandrixGaebString): TLandrixGaebString;

{ OZ parts are compared right-aligned (left-padded with spaces, the lowest
  character of the OZ sort order); parts of digits only by value.
  DE: OZ-Teile werden rechtsbuendig verglichen (links mit Leerzeichen
  aufgefuellt, dem kleinsten Zeichen der OZ-Sortierfolge); Teile nur aus
  Ziffern nach ihrem Wert. }
function LandrixGaebComparePart(const A, B: TLandrixGaebString): Integer;

{ Order of two OZ: part by part (LandrixGaebComparePart), a shorter OZ
  first, then the index.
  DE: Reihenfolge zweier OZ: Teil fuer Teil (LandrixGaebComparePart), eine
  kuerzere OZ zuerst, dann der Index. }
function LandrixGaebCompareOZ(A, B: TLandrixGaebTreeNode): Integer;

{ Part of an OZ as it enters the key: parts of digits only by value, as in
  LandrixGaebComparePart, so that uniqueness, order and pair matching
  agree.
  DE: OZ-Teil fuer den Schluessel: Teile nur aus Ziffern nach ihrem Wert
  wie in LandrixGaebComparePart, damit Eindeutigkeit, Reihenfolge und
  Paarzuordnung uebereinstimmen. }
function LandrixGaebKeyPart(const APart: TLandrixGaebString): TLandrixGaebString;

{ Key of a category or item for matching two documents: categories and
  items with the same OZ do not match each other.
  DE: Schluessel eines Bereichs oder einer Position fuer die Zuordnung
  zweier Dokumente: Bereiche und Positionen mit gleicher OZ werden
  einander nicht zugeordnet. }
function LandrixGaebMatchKey(ANode: TLandrixGaebTreeNode): TLandrixGaebString;

{ Amount of a category: TotAfterDisc, else TotalLSUM, else Total; False if
  there is none.
  DE: Betrag eines Bereichs: TotAfterDisc, sonst TotalLSUM, sonst Total;
  False, wenn keiner vorliegt. }
function LandrixGaebCtgyAmount(ACtgy: TLandrixGaebXmlBoQCtgy; out AAmount: TLandrixXmlDecimal): Boolean;

{ Total of an item or markup item (IT), or the amount of a category; False
  if there is none.
  DE: Gesamtbetrag einer Position oder Zuschlagsposition (IT) bzw. Betrag
  eines Bereichs; False, wenn keiner vorliegt. }
function LandrixGaebNodeAmount(ANode: TLandrixGaebTreeNode; out AAmount: TLandrixXmlDecimal): Boolean;

{ True if a serial number of an alternative is set and not 0.
  DE: True, wenn die Nummer einer Alternative gesetzt und nicht 0 ist. }
function LandrixGaebIsAlternative(const ASerNo: TLandrixGaebString): Boolean;

{ True if a node with the kinds of a request (all phases but X84) is not
  part of the totals: alternative items and categories (serial number
  other than 0), eventual items without total, items and categories not
  applicable, items of a variant bid that are not required (AlterBidStatus
  N/A, documentation 4.6.15).
  DE: True, wenn ein Knoten mit den Kennzeichen einer Anfrage (alle Phasen
  ausser X84) nicht in die Summen eingeht: Alternativpositionen und
  -bereiche (Nummer ungleich 0), Bedarfspositionen ohne Gesamtbetrag,
  entfallende Positionen und Bereiche, im Nebenangebot nicht erforderliche
  Positionen (AlterBidStatus N/A, Dokumentation 4.6.15). }
function LandrixGaebNotCounted(ANode: TLandrixGaebTreeNode): Boolean;

{ True if the award marks a node as accepted alternative or rejected basis
  (Accepted). The documentation gives no rule for the totals then.
  DE: True, wenn der Auftrag einen Knoten als beauftragte Alternative oder
  zurueckgestellte Grundausfuehrung kennzeichnet (Accepted). Fuer die
  Summen gibt die Dokumentation dann keine Regel. }
function LandrixGaebHasAccepted(ANode: TLandrixGaebTreeNode): Boolean;

implementation

function IntToUtf8(N: Integer): TLandrixXmlUtf8;
begin
  Result := LandrixXmlStringToUtf8(IntToStr(N));
end;

function IntOf(const S: TLandrixGaebString; ADefault: Integer): Integer;
begin
  Result := StrToIntDef(Trim(LandrixXmlUtf8ToString(LandrixXmlWideToUtf8(S))), ADefault);
end;

function XDec(const A: TLandrixGaebDecimal): TLandrixXmlDecimal;
begin
  Result := A.AsXmlDecimal;
end;

function LandrixGaebIsDigits(const S: TLandrixGaebString): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to Length(S) do
    if (S[I] < '0') or (S[I] > '9') then
      Exit;
  Result := S <> '';
end;

function LandrixGaebStripZeros(const S: TLandrixGaebString): TLandrixGaebString;
var
  I: Integer;
begin
  I := 1;
  while (I <= Length(S)) and (S[I] = '0') do
    Inc(I);
  Result := Copy(S, I, MaxInt);
end;

function LandrixGaebComparePart(const A, B: TLandrixGaebString): Integer;
var
  I, N: Integer;
  CA, CB: TLandrixGaebChar;
  SA, SB: TLandrixGaebString;
begin
  if LandrixGaebIsDigits(A) and LandrixGaebIsDigits(B) then
  begin
    { numeric parts by value, with or without leading zeros }
    SA := LandrixGaebStripZeros(A);
    SB := LandrixGaebStripZeros(B);
    Result := Length(SA) - Length(SB);
    if (Result = 0) and (SA <> SB) then
    begin
      if SA < SB then
        Result := -1
      else
        Result := 1;
    end;
    Exit;
  end;
  N := Length(A);
  if Length(B) > N then
    N := Length(B);
  for I := 0 to N - 1 do
  begin
    CA := ' ';
    CB := ' ';
    if I >= N - Length(A) then
      CA := A[I - (N - Length(A)) + 1];
    if I >= N - Length(B) then
      CB := B[I - (N - Length(B)) + 1];
    if CA <> CB then
    begin
      if CA < CB then
        Result := -1
      else
        Result := 1;
      Exit;
    end;
  end;
  Result := 0;
end;

function LandrixGaebCompareOZ(A, B: TLandrixGaebTreeNode): Integer;
var
  I: Integer;
begin
  I := 0;
  while (I < Length(A.Parts)) and (I < Length(B.Parts)) do
  begin
    Result := LandrixGaebComparePart(A.Parts[I], B.Parts[I]);
    if Result <> 0 then
      Exit;
    Inc(I);
  end;
  Result := Integer(Length(A.Parts)) - Integer(Length(B.Parts));
  if Result = 0 then
    Result := LandrixGaebComparePart(A.Index, B.Index);
end;

function LandrixGaebKeyPart(const APart: TLandrixGaebString): TLandrixGaebString;
begin
  Result := APart;
  if LandrixGaebIsDigits(APart) then
  begin
    Result := LandrixGaebStripZeros(APart);
    if Result = '' then
      Result := '0';
  end;
end;

function LandrixGaebMatchKey(ANode: TLandrixGaebTreeNode): TLandrixGaebString;
begin
  if ANode.Kind = LandrixGaebTreeCtgy then
    Result := 'C:' + ANode.Key
  else
    Result := 'I:' + ANode.Key;
end;

function LandrixGaebCtgyAmount(ACtgy: TLandrixGaebXmlBoQCtgy; out AAmount: TLandrixXmlDecimal): Boolean;
begin
  Result := False;
  if not ACtgy.HasTotals then
    Exit;
  if ACtgy.Totals.TotAfterDisc.HasValue then
    AAmount := XDec(ACtgy.Totals.TotAfterDisc)
  else if ACtgy.Totals.TotalLSUM.HasValue then
    AAmount := XDec(ACtgy.Totals.TotalLSUM)
  else if ACtgy.Totals.Total.HasValue then
    AAmount := XDec(ACtgy.Totals.Total)
  else
    Exit;
  Result := True;
end;

function LandrixGaebNodeAmount(ANode: TLandrixGaebTreeNode; out AAmount: TLandrixXmlDecimal): Boolean;
begin
  Result := False;
  case ANode.Kind of
    LandrixGaebTreeItem:
      begin
        Result := TLandrixGaebXmlItem(ANode.Node).IT.HasValue;
        if Result then
          AAmount := XDec(TLandrixGaebXmlItem(ANode.Node).IT);
      end;
    LandrixGaebTreeMarkup:
      begin
        Result := TLandrixGaebXmlMarkupItem(ANode.Node).IT.HasValue;
        if Result then
          AAmount := XDec(TLandrixGaebXmlMarkupItem(ANode.Node).IT);
      end;
    LandrixGaebTreeCtgy:
      Result := LandrixGaebCtgyAmount(TLandrixGaebXmlBoQCtgy(ANode.Node), AAmount);
  else
    ;
  end;
end;

function LandrixGaebIsAlternative(const ASerNo: TLandrixGaebString): Boolean;
begin
  Result := (ASerNo <> '') and (IntOf(ASerNo, 0) <> 0);
end;

function LandrixGaebNotCounted(ANode: TLandrixGaebTreeNode): Boolean;
begin
  Result := False;
  if ANode = nil then
    Exit;
  case ANode.Kind of
    LandrixGaebTreeItem:
      Result := LandrixGaebIsAlternative(TLandrixGaebXmlItem(ANode.Node).ALNSerNo) or
        (TLandrixGaebXmlItem(ANode.Node).Provis = 'WithoutTotal') or
        (TLandrixGaebXmlItem(ANode.Node).NotAppl = 'Yes') or
        (TLandrixGaebXmlItem(ANode.Node).AlterBidStatus = 'N/A');
    LandrixGaebTreeMarkup:
      Result := LandrixGaebIsAlternative(TLandrixGaebXmlMarkupItem(ANode.Node).ALNSerNo) or
        (TLandrixGaebXmlMarkupItem(ANode.Node).Provis = 'WithoutTotal') or
        (TLandrixGaebXmlMarkupItem(ANode.Node).NotAppl = 'Yes');
    LandrixGaebTreeCtgy:
      Result := LandrixGaebIsAlternative(TLandrixGaebXmlBoQCtgy(ANode.Node).ALNBSerNo) or
        (TLandrixGaebXmlBoQCtgy(ANode.Node).NotApplBoQ = 'Yes');
  else
    ;
  end;
end;

function LandrixGaebHasAccepted(ANode: TLandrixGaebTreeNode): Boolean;
begin
  Result := False;
  case ANode.Kind of
    LandrixGaebTreeItem:
      Result := TLandrixGaebXmlItem(ANode.Node).Accepted <> '';
    LandrixGaebTreeMarkup:
      Result := TLandrixGaebXmlMarkupItem(ANode.Node).Accepted <> '';
    LandrixGaebTreeCtgy:
      Result := TLandrixGaebXmlBoQCtgy(ANode.Node).Accepted <> '';
  else
    ;
  end;
end;

{ TLandrixGaebKeyIndex }

procedure TLandrixGaebKeyIndex.Add(const AKey: TLandrixGaebString; ANode: TLandrixGaebTreeNode);
begin
  if FCount >= Length(FKeys) then
  begin
    SetLength(FKeys, FCount * 2 + 16);
    SetLength(FNodes, FCount * 2 + 16);
  end;
  FKeys[FCount] := AKey;
  FNodes[FCount] := ANode;
  Inc(FCount);
end;

function TLandrixGaebKeyIndex.Less(I, J: Integer): Boolean;
begin
  if FKeys[I] <> FKeys[J] then
    Result := FKeys[I] < FKeys[J]
  else
    Result := FNodes[I].Order < FNodes[J].Order;
end;

procedure TLandrixGaebKeyIndex.Swap(I, J: Integer);
var
  K: TLandrixGaebString;
  N: TLandrixGaebTreeNode;
begin
  K := FKeys[I];
  FKeys[I] := FKeys[J];
  FKeys[J] := K;
  N := FNodes[I];
  FNodes[I] := FNodes[J];
  FNodes[J] := N;
end;

procedure TLandrixGaebKeyIndex.QuickSort(L, R: Integer);
var
  I, J, P: Integer;
begin
  while L < R do
  begin
    { median element as pivot, moved to the end }
    Swap((L + R) div 2, R);
    P := R;
    I := L;
    for J := L to R - 1 do
      if Less(J, P) then
      begin
        Swap(I, J);
        Inc(I);
      end;
    Swap(I, R);
    if I - L < R - I then
    begin
      QuickSort(L, I - 1);
      L := I + 1;
    end
    else
    begin
      QuickSort(I + 1, R);
      R := I - 1;
    end;
  end;
end;

procedure TLandrixGaebKeyIndex.Sort;
begin
  QuickSort(0, FCount - 1);
end;

function TLandrixGaebKeyIndex.Find(const AKey: TLandrixGaebString): TLandrixGaebTreeNode;
var
  Lo, Hi, Mid: Integer;
begin
  Lo := 0;
  Hi := FCount - 1;
  while Lo < Hi do
  begin
    Mid := (Lo + Hi) div 2;
    if FKeys[Mid] < AKey then
      Lo := Mid + 1
    else
      Hi := Mid;
  end;
  Result := nil;
  if (Lo < FCount) and (FKeys[Lo] = AKey) then
    Result := FNodes[Lo];
end;

function TLandrixGaebKeyIndex.Key(I: Integer): TLandrixGaebString;
begin
  Result := FKeys[I];
end;

function TLandrixGaebKeyIndex.Node(I: Integer): TLandrixGaebTreeNode;
begin
  Result := FNodes[I];
end;

{ TLandrixGaebTree }

constructor TLandrixGaebTree.Create(ADocument: TLandrixGaebXmlGAEB);
var
  BoQPath: TLandrixXmlUtf8;
begin
  inherited Create;
  FNodes := TObjectList.Create;
  FRoot := TLandrixGaebTreeNode.Create;
  FRoot.Kind := LandrixGaebTreeRoot;
  FRoot.SumKnown := True;
  FRoot.Sum := LandrixXmlDecimalZero;
  BoQPath := '/GAEB[1]/Award[1]/BoQ[1]';
  FRoot.Path := BoQPath;
  FInfoPath := BoQPath + '/BoQInfo[1]';
  if not ADocument.HasAward or not ADocument.Award.HasBoQ then
    Exit;
  if ADocument.Award.BoQ.HasBoQBody then
    WalkBody(ADocument.Award.BoQ.BoQBody, FRoot, BoQPath + '/BoQBody[1]');
end;

destructor TLandrixGaebTree.Destroy;
begin
  FRoot.Free;
  FNodes.Free;
  inherited Destroy;
end;

function TLandrixGaebTree.AddNode(ANode: TLandrixGaebXmlNode; AKind: Integer; AParent: TLandrixGaebTreeNode;
  const APath: TLandrixXmlUtf8; const APart, AIndex: TLandrixGaebString): TLandrixGaebTreeNode;
var
  I: Integer;
begin
  Result := TLandrixGaebTreeNode.Create;
  FNodes.Add(Result);
  Result.Node := ANode;
  Result.Kind := AKind;
  Result.Parent := AParent;
  Result.Path := APath;
  Result.Order := Integer(FNodes.Count);
  Result.SumKnown := True;
  Result.Sum := LandrixXmlDecimalZero;
  if (AKind = LandrixGaebTreePerf) or (AKind = LandrixGaebTreeRemark) then
    Exit;
  SetLength(Result.Parts, Length(AParent.Parts) + 1);
  for I := 0 to Integer(High(AParent.Parts)) do
    Result.Parts[I] := AParent.Parts[I];
  Result.Parts[High(Result.Parts)] := APart;
  Result.Index := AIndex;
  Result.Key := '';
  for I := 0 to Integer(High(Result.Parts)) do
  begin
    if I > 0 then
      Result.Key := Result.Key + '.';
    Result.Key := Result.Key + LandrixGaebKeyPart(Result.Parts[I]);
  end;
  if AIndex <> '' then
    Result.Key := Result.Key + '#' + AIndex;
end;

procedure TLandrixGaebTree.WalkBody(ABody: TLandrixGaebXmlBoQBody; AParent: TLandrixGaebTreeNode;
  const APath: TLandrixXmlUtf8);
var
  I, Ctgys, Perfs, Remarks: Integer;
  N: TLandrixGaebXmlNode;
  R: TLandrixGaebTreeNode;
begin
  Ctgys := 0;
  Perfs := 0;
  Remarks := 0;
  for I := 0 to Integer(ABody.Children.Count) - 1 do
  begin
    N := ABody.Children[I];
    if N is TLandrixGaebXmlBoQCtgy then
    begin
      Inc(Ctgys);
      R := AddNode(N, LandrixGaebTreeCtgy, AParent, APath + '/BoQCtgy[' + IntToUtf8(Ctgys) + ']',
        TLandrixGaebXmlBoQCtgy(N).RNoPart, '');
      if TLandrixGaebXmlBoQCtgy(N).HasBoQBody then
        WalkBody(TLandrixGaebXmlBoQCtgy(N).BoQBody, R, R.Path + '/BoQBody[1]');
    end
    else if N is TLandrixGaebXmlPerfDescr then
    begin
      Inc(Perfs);
      AddNode(N, LandrixGaebTreePerf, AParent, APath + '/PerfDescr[' + IntToUtf8(Perfs) + ']', '', '');
    end
    else if N is TLandrixGaebXmlRemark then
    begin
      Inc(Remarks);
      AddNode(N, LandrixGaebTreeRemark, AParent, APath + '/Remark[' + IntToUtf8(Remarks) + ']', '', '');
    end;
  end;
  if ABody.HasItemlist then
    WalkItems(ABody.Itemlist, AParent, APath + '/Itemlist[1]');
end;

procedure TLandrixGaebTree.WalkItems(AList: TLandrixGaebXmlItemlist; AParent: TLandrixGaebTreeNode;
  const APath: TLandrixXmlUtf8);
var
  I, Items, Markups, Perfs, Remarks: Integer;
  N: TLandrixGaebXmlNode;
begin
  Items := 0;
  Markups := 0;
  Perfs := 0;
  Remarks := 0;
  for I := 0 to Integer(AList.Children.Count) - 1 do
  begin
    N := AList.Children[I];
    if N is TLandrixGaebXmlItem then
    begin
      Inc(Items);
      AddNode(N, LandrixGaebTreeItem, AParent, APath + '/Item[' + IntToUtf8(Items) + ']',
        TLandrixGaebXmlItem(N).RNoPart, TLandrixGaebXmlItem(N).RNoIndex);
    end
    else if N is TLandrixGaebXmlMarkupItem then
    begin
      Inc(Markups);
      AddNode(N, LandrixGaebTreeMarkup, AParent, APath + '/MarkupItem[' + IntToUtf8(Markups) + ']',
        TLandrixGaebXmlMarkupItem(N).RNoPart, TLandrixGaebXmlMarkupItem(N).RNoIndex);
    end
    else if N is TLandrixGaebXmlPerfDescr then
    begin
      Inc(Perfs);
      AddNode(N, LandrixGaebTreePerf, AParent, APath + '/PerfDescr[' + IntToUtf8(Perfs) + ']', '', '');
    end
    else if N is TLandrixGaebXmlRemark then
    begin
      Inc(Remarks);
      AddNode(N, LandrixGaebTreeRemark, AParent, APath + '/Remark[' + IntToUtf8(Remarks) + ']', '', '');
    end;
  end;
end;

end.
