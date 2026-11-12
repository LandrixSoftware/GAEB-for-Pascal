{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Process functions on bills of quantities of the business facade:
  matching the nodes of two documents by OZ, computing the totals of
  categories and of the bill with the counting rule, and building the
  award (X86) from request (X83) and bid (X84).

  DE: Prozessfunktionen auf Leistungsverzeichnissen der fachlichen Fassade:
  Zuordnung der Knoten zweier Dokumente ueber die OZ, Berechnung der Summen
  von Bereichen und LV mit der Zaehlregel und Zusammensetzen des Auftrags
  (X86) aus Anfrage (X83) und Angebot (X84). }

{ API: internal. May change in any release before 1.0 (becomes stable with
  the API review of phase 4).
  DE: API: intern. Kann sich vor Version 1.0 in jeder Version aendern (wird
  mit dem API-Review der Phase 4 stabil). }

unit LandrixGaebProcess;

{$I LandrixGaeb.inc}

interface

uses
  Contnrs,
  LandrixGaebTypes,
  LandrixGaebDiagnostics,
  LandrixGaebBoQ;

type
  { How a node was matched: a pair (one node with the key on each side),
    only in the left or only in the right document, or ambiguous (the key
    occurs more than once on a side; such nodes are never paired).
    DE: Wie ein Knoten zugeordnet wurde: ein Paar (auf jeder Seite ein
    Knoten mit dem Schluessel), nur im linken oder nur im rechten Dokument,
    oder mehrdeutig (der Schluessel kommt auf einer Seite mehrfach vor;
    solche Knoten werden nie gepaart). }
  TLandrixGaebMatchKind = (gmkPair, gmkOnlyLeft, gmkOnlyRight, gmkAmbiguous);

  { One entry of a matching. Left and Right are set for a pair; otherwise
    only the node of its side. A pair can join an item and a markup item
    with the same OZ: compare Kind.
    DE: Ein Eintrag einer Zuordnung. Bei einem Paar sind Left und Right
    gesetzt, sonst nur der Knoten seiner Seite. Ein Paar kann eine Position
    und eine Zuschlagsposition mit gleicher OZ verbinden: Kind vergleichen. }
  TLandrixGaebMatch = record
    Kind: TLandrixGaebMatchKind;
    Left: TLandrixGaebNode;
    Right: TLandrixGaebNode;
  end;

  { The categories, items and markup items of two bills matched by
    TLandrixGaebNode.OZKey, the rule of the pair rules. Entries: the nodes
    of the left bill in document order, then the right nodes without a
    pair in document order. Remarks and execution descriptions are not
    matched. The matching holds views of both bills: AddCategory, AddItem,
    Remove or Refresh on either bill make it stale; create a new one.
    DE: Die Bereiche, Positionen und Zuschlagspositionen zweier LV,
    zugeordnet ueber TLandrixGaebNode.OZKey, die Regel der Paarregeln.
    Eintraege: die Knoten des linken LV in Dokumentreihenfolge, dann die
    rechten Knoten ohne Paar in Dokumentreihenfolge. Bemerkungen und
    Ausfuehrungsbeschreibungen werden nicht zugeordnet. Die Zuordnung haelt
    Sichten beider LV: AddCategory, AddItem, Remove oder Refresh an einem
    der beiden machen sie ungueltig; dann eine neue anlegen. }
  TLandrixGaebMatching = class(TObject)
  private
    FLeft: TLandrixGaebBillOfQuantities;
    FRight: TLandrixGaebBillOfQuantities;
    FLeftKeys: TObject;
    FRightKeys: TObject;
    FCarriers: TObjectList;
    FEntries: array of TLandrixGaebMatch;
    FCount: Integer;
    procedure Fill(ABill: TLandrixGaebBillOfQuantities; AKeys: TObject);
    procedure AddEntry(AKind: TLandrixGaebMatchKind; ALeft, ARight: TLandrixGaebNode);
  public
    { Matches ALeft and ARight (neither owned; both must outlive the
      matching). DE: Ordnet ALeft und ARight einander zu (nicht im Besitz;
      beide muessen die Zuordnung ueberleben). }
    constructor Create(ALeft, ARight: TLandrixGaebBillOfQuantities);
    { Frees the matching, not the bills. DE: Gibt die Zuordnung frei, nicht
      die LV. }
    destructor Destroy; override;
    { The two bills. DE: Die beiden LV. }
    property Left: TLandrixGaebBillOfQuantities read FLeft;
    property Right: TLandrixGaebBillOfQuantities read FRight;
    { Number of entries and the entry at AIndex (from 0).
      DE: Anzahl der Eintraege und der Eintrag an AIndex (ab 0). }
    function Count: Integer;
    function Entries(AIndex: Integer): TLandrixGaebMatch;
    { Number of entries of a kind. DE: Anzahl der Eintraege einer Art. }
    function CountOf(AKind: TLandrixGaebMatchKind): Integer;
    { The partner of ANode (a node of either bill) if it is part of a pair,
      else nil. DE: Der Partner von ANode (ein Knoten eines der beiden LV),
      wenn er Teil eines Paares ist, sonst nil. }
    function PartnerOf(ANode: TLandrixGaebNode): TLandrixGaebNode;
  end;

  { A computed sum: Known with the value, or not known with the node that
    makes it unknown (Blocker; nil only if the sum does not fit a
    TLandrixGaebDecimal).
    DE: Eine berechnete Summe: Known mit dem Wert, oder nicht bekannt mit
    dem Knoten, der sie unbekannt macht (Blocker; nil nur, wenn die Summe
    nicht in ein TLandrixGaebDecimal passt). }
  TLandrixGaebSum = record
    Known: Boolean;
    Value: TLandrixGaebDecimal;
    Blocker: TLandrixGaebNode;
  end;

{ Sum of the children of ACategory (nil: the top level of ABill) that
  count, by the counting rule of the pair rules. Whether a child counts
  comes from its own kinds (AKinds nil) or from its partner in AKinds,
  whose Right must be ABill (a bid takes the kinds of its request). A
  child that does not count is skipped; a child with unknown status, a
  child without partner in AKinds, an item or markup item without IT
  (unless not offered) and a category with a discount but without
  TotAfterDisc make the sum unknown. An item adds IT; a category adds
  TotAfterDisc, else TotalLSUM, else its own computed sum. Never rounds.
  DE: Summe der zaehlenden Kinder von ACategory (nil: oberste Ebene von
  ABill) nach der Zaehlregel der Paarregeln. Ob ein Kind zaehlt, ergibt
  sich aus seinen eigenen Kennzeichen (AKinds nil) oder aus seinem Partner
  in AKinds, dessen Right ABill sein muss (ein Angebot nimmt die
  Kennzeichen seiner Anfrage). Ein nicht zaehlendes Kind wird
  uebersprungen; ein Kind mit unbestimmtem Status, ein Kind ohne Partner
  in AKinds, eine Position oder Zuschlagsposition ohne IT (ausser nicht
  angeboten) und ein Bereich mit Nachlass ohne TotAfterDisc machen die
  Summe unbekannt. Eine Position traegt IT bei, ein Bereich TotAfterDisc,
  sonst TotalLSUM, sonst seine eigene berechnete Summe. Rundet nie. }
function LandrixGaebComputeSum(ABill: TLandrixGaebBillOfQuantities; ACategory: TLandrixGaebCategory;
  AKinds: TLandrixGaebMatching): TLandrixGaebSum;

{ Writes the computed sum (LandrixGaebComputeSum) as Total of every
  category and of the bill where it is known; other values of the totals
  blocks stay. Returns the number of totals left unwritten because the
  sum is unknown.
  DE: Schreibt die berechnete Summe (LandrixGaebComputeSum) als Total
  jedes Bereichs und des LV, wo sie bekannt ist; andere Werte der
  Summenbloecke bleiben. Liefert die Anzahl der nicht geschriebenen
  Summen, weil die Summe unbekannt ist. }
function LandrixGaebApplyTotals(ABill: TLandrixGaebBillOfQuantities; AKinds: TLandrixGaebMatching): Integer;

{ Builds the award (X86, version and edition of the request) from a
  request (X83) and a bid (X84): the request written as X86 and read back
  (texts, quantities, structure, owner; what an X86 does not allow, such
  as OpenDate, is dropped with the writer's GAEB-WRT-001), then from the
  bid, matched by OZ: unit prices and their components, discount, item
  totals, quantities of items with QtyTBD, the same values of sub
  descriptions (by number), the bidder's text complements of items and
  sub descriptions (by number; a text body becomes one paragraph), markup,
  ITMarkup, discount and total of markup items, the values of the totals
  blocks of categories and of the bill (TLandrixGaebTotalField) and the
  address of the contractor (CTR). Not taken: bidder comments, VAT parts,
  totals of unit price components and other parts of the bid.
  ADiagnostics (may be nil) gets the findings of writing and reading back
  with their severity (but the replaced DP) and the warnings GAEB-PRC-001
  (element of the bid not in the request), GAEB-PRC-002 (OZ ambiguous),
  GAEB-PRC-003 (item and markup item with the same OZ), such elements
  take nothing over, and GAEB-PRC-004 (markup item of the award without
  Markup or ITMarkup, which an X86 requires). ELandrixGaebError if the
  request is no X83 or the bid no X84. The result owns its document.
  DE: Setzt den Auftrag (X86, Version und Ausgabe der Anfrage) aus einer
  Anfrage (X83) und einem Angebot (X84) zusammen: die Anfrage als X86
  geschrieben und zurueckgelesen (Texte, Mengen, Struktur, Auftraggeber;
  was eine X86 nicht erlaubt, etwa OpenDate, entfaellt mit GAEB-WRT-001
  des Schreibers), dann aus dem Angebot, zugeordnet ueber die OZ:
  Einheitspreise und ihre Anteile, Nachlass, Gesamtbetraege, Mengen von
  Positionen mit QtyTBD, dieselben Werte der Unterbeschreibungen (nach
  Nummer), die Bieterergaenzungen von Positionen und
  Unterbeschreibungen (nach Nummer; ein Textinhalt wird ein Absatz),
  Zuschlag, ITMarkup, Nachlass und Gesamtbetrag der Zuschlagspositionen,
  die Werte der Summenbloecke von Bereichen und LV
  (TLandrixGaebTotalField) und die Anschrift des Auftragnehmers (CTR).
  Nicht uebernommen: Bieterkommentare, Mehrwertsteueranteile, Summen der
  EP-Anteile und andere Teile des Angebots. ADiagnostics (darf nil sein)
  erhaelt die Meldungen von Schreiben und Zurueckliesen mit ihrer Schwere
  (ausser dem ersetzten DP) und die Warnungen GAEB-PRC-001 (Element des
  Angebots nicht in der Anfrage), GAEB-PRC-002 (OZ mehrdeutig),
  GAEB-PRC-003 (Position und Zuschlagsposition mit gleicher OZ), solche
  Elemente uebernehmen nichts, und GAEB-PRC-004 (Zuschlagsposition des
  Auftrags ohne Markup oder ITMarkup, die eine X86 verlangt).
  ELandrixGaebError, wenn die Anfrage keine X83 oder das Angebot keine X84
  ist. Das Ergebnis besitzt sein Dokument. }
function LandrixGaebBuildAward(ARequest, ABid: TLandrixGaebBillOfQuantities;
  ADiagnostics: TLandrixGaebDiagnostics): TLandrixGaebBillOfQuantities;

implementation

uses
  SysUtils,
  Classes,
  LandrixXmlBase,
  LandrixXmlDecimal,
  LandrixGaebDetect,
  LandrixGaebXmlModel,
  LandrixGaebXmlWriteBase,
  LandrixGaebXmlWriter,
  LandrixGaebXmlReader,
  LandrixGaebBoQTree;

{ TLandrixGaebMatching }

constructor TLandrixGaebMatching.Create(ALeft, ARight: TLandrixGaebBillOfQuantities);
var
  LeftKeys, RightKeys: TLandrixGaebKeyIndex;
  I, NL, NR: Integer;
  N: TLandrixGaebNode;
  Key: TLandrixGaebString;

  function KeyCount(AKeys: TLandrixGaebKeyIndex; const AKey: TLandrixGaebString): Integer;
  var
    K: Integer;
  begin
    Result := 0;
    K := AKeys.IndexOf(AKey);
    if K < 0 then
      Exit;
    while (K < AKeys.Count) and (AKeys.Key(K) = AKey) do
    begin
      Inc(Result);
      Inc(K);
    end;
  end;

begin
  inherited Create;
  FLeft := ALeft;
  FRight := ARight;
  FCarriers := TObjectList.Create(True);
  LeftKeys := TLandrixGaebKeyIndex.Create;
  FLeftKeys := LeftKeys;
  RightKeys := TLandrixGaebKeyIndex.Create;
  FRightKeys := RightKeys;
  Fill(ALeft, LeftKeys);
  Fill(ARight, RightKeys);
  for I := 0 to ALeft.NodeCount - 1 do
  begin
    N := ALeft.Nodes(I);
    Key := N.OZKey;
    if Key = '' then
      Continue;
    NL := KeyCount(LeftKeys, Key);
    NR := KeyCount(RightKeys, Key);
    if (NL > 1) or (NR > 1) then
      AddEntry(gmkAmbiguous, N, nil)
    else if NR = 1 then
      AddEntry(gmkPair, N, ARight.Nodes(RightKeys.Find(Key).Order))
    else
      AddEntry(gmkOnlyLeft, N, nil);
  end;
  for I := 0 to ARight.NodeCount - 1 do
  begin
    N := ARight.Nodes(I);
    Key := N.OZKey;
    if Key = '' then
      Continue;
    NL := KeyCount(LeftKeys, Key);
    NR := KeyCount(RightKeys, Key);
    if (NL > 1) or (NR > 1) then
      AddEntry(gmkAmbiguous, nil, N)
    else if NL = 0 then
      AddEntry(gmkOnlyRight, nil, N);
  end;
end;

destructor TLandrixGaebMatching.Destroy;
begin
  FLeftKeys.Free;
  FRightKeys.Free;
  FCarriers.Free;
  inherited Destroy;
end;

{ The nodes with a key; a carrier tree node holds the position of the node
  in the bill (Order). }
procedure TLandrixGaebMatching.Fill(ABill: TLandrixGaebBillOfQuantities; AKeys: TObject);
var
  I: Integer;
  Key: TLandrixGaebString;
  Carrier: TLandrixGaebTreeNode;
begin
  for I := 0 to ABill.NodeCount - 1 do
  begin
    Key := ABill.Nodes(I).OZKey;
    if Key = '' then
      Continue;
    Carrier := TLandrixGaebTreeNode.Create;
    FCarriers.Add(Carrier);
    Carrier.Order := I;
    TLandrixGaebKeyIndex(AKeys).Add(Key, Carrier);
  end;
  TLandrixGaebKeyIndex(AKeys).Sort;
end;

procedure TLandrixGaebMatching.AddEntry(AKind: TLandrixGaebMatchKind; ALeft, ARight: TLandrixGaebNode);
begin
  if FCount = Length(FEntries) then
    SetLength(FEntries, 2 * FCount + 16);
  FEntries[FCount].Kind := AKind;
  FEntries[FCount].Left := ALeft;
  FEntries[FCount].Right := ARight;
  Inc(FCount);
end;

function TLandrixGaebMatching.Count: Integer;
begin
  Result := FCount;
end;

function TLandrixGaebMatching.Entries(AIndex: Integer): TLandrixGaebMatch;
begin
  if (AIndex < 0) or (AIndex >= FCount) then
    raise ELandrixGaebError.Create('match index out of range');
  Result := FEntries[AIndex];
end;

function TLandrixGaebMatching.CountOf(AKind: TLandrixGaebMatchKind): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to FCount - 1 do
    if FEntries[I].Kind = AKind then
      Inc(Result);
end;

function TLandrixGaebMatching.PartnerOf(ANode: TLandrixGaebNode): TLandrixGaebNode;
var
  Own, Other: TLandrixGaebKeyIndex;
  OtherBill: TLandrixGaebBillOfQuantities;
  Key: TLandrixGaebString;
  K: Integer;
begin
  Result := nil;
  if ANode = nil then
    Exit;
  if ANode.Bill = FLeft then
  begin
    Own := TLandrixGaebKeyIndex(FLeftKeys);
    Other := TLandrixGaebKeyIndex(FRightKeys);
    OtherBill := FRight;
  end
  else if ANode.Bill = FRight then
  begin
    Own := TLandrixGaebKeyIndex(FRightKeys);
    Other := TLandrixGaebKeyIndex(FLeftKeys);
    OtherBill := FLeft;
  end
  else
    Exit;
  Key := ANode.OZKey;
  if Key = '' then
    Exit;
  { a pair: the key exactly once on each side; the node itself is then the
    only node with the key on its side }
  K := Own.IndexOf(Key);
  if (K < 0) or ((K + 1 < Own.Count) and (Own.Key(K + 1) = Key)) then
    Exit;
  K := Other.IndexOf(Key);
  if (K < 0) or ((K + 1 < Other.Count) and (Other.Key(K + 1) = Key)) then
    Exit;
  Result := OtherBill.Nodes(Other.Node(K).Order);
end;

{ Sums }

function ToGaebDecimal(const A: TLandrixXmlDecimal; out AValue: TLandrixGaebDecimal): Boolean;
begin
  AValue.Clear;
  Result := AValue.TrySetText(LandrixXmlFormatDecimal(A));
end;

function StatusOf(ANode: TLandrixGaebNode; AKinds: TLandrixGaebMatching): TLandrixGaebCountStatus;
var
  K: TLandrixGaebNode;
begin
  K := ANode;
  if AKinds <> nil then
  begin
    K := AKinds.PartnerOf(ANode);
    if (K = nil) or (K.Kind <> ANode.Kind) then
    begin
      Result := gcsUnknown;
      Exit;
    end;
  end;
  if K is TLandrixGaebCategory then
    Result := TLandrixGaebCategory(K).CountStatus
  else if K is TLandrixGaebItem then
    Result := TLandrixGaebItem(K).CountStatus
  else
    Result := TLandrixGaebMarkupItem(K).CountStatus;
end;

procedure ComputeInto(ABill: TLandrixGaebBillOfQuantities; ACategory: TLandrixGaebCategory;
  AKinds: TLandrixGaebMatching; var ASum: TLandrixXmlDecimal; out ABlocker: TLandrixGaebNode); forward;

{ What a counting node adds; False with ABlocker if unknown.
  DE: Was ein zaehlender Knoten beitraegt; False mit ABlocker, wenn
  unbekannt. }
function Contribution(ABill: TLandrixGaebBillOfQuantities; ANode: TLandrixGaebNode;
  AKinds: TLandrixGaebMatching; out AAmount: TLandrixXmlDecimal; out ABlocker: TLandrixGaebNode): Boolean;
var
  Item: TLandrixGaebItem;
  Markup: TLandrixGaebMarkupItem;
  Ctgy: TLandrixGaebCategory;
  T: TLandrixGaebTotals;
begin
  Result := False;
  ABlocker := ANode;
  AAmount := LandrixXmlDecimalZero;
  if ANode is TLandrixGaebItem then
  begin
    Item := TLandrixGaebItem(ANode);
    if Item.IT.HasValue then
      AAmount := Item.IT.AsXmlDecimal
    else if not Item.NotOffered then
      Exit;
  end
  else if ANode is TLandrixGaebMarkupItem then
  begin
    Markup := TLandrixGaebMarkupItem(ANode);
    if not Markup.IT.HasValue then
      Exit;
    AAmount := Markup.IT.AsXmlDecimal;
  end
  else
  begin
    Ctgy := TLandrixGaebCategory(ANode);
    T := Ctgy.Totals;
    if T.Value(gtfTotAfterDisc).HasValue then
      AAmount := T.Value(gtfTotAfterDisc).AsXmlDecimal
    else if T.Value(gtfTotalLSUM).HasValue then
      AAmount := T.Value(gtfTotalLSUM).AsXmlDecimal
    else if T.Value(gtfDiscountPcnt).HasValue or T.Value(gtfDiscountAmt).HasValue then
      Exit
    else
    begin
      ComputeInto(ABill, Ctgy, AKinds, AAmount, ABlocker);
      Result := ABlocker = nil;
      Exit;
    end;
  end;
  ABlocker := nil;
  Result := True;
end;

procedure ComputeInto(ABill: TLandrixGaebBillOfQuantities; ACategory: TLandrixGaebCategory;
  AKinds: TLandrixGaebMatching; var ASum: TLandrixXmlDecimal; out ABlocker: TLandrixGaebNode);
var
  List: TLandrixGaebNodeList;
  I: Integer;
  N: TLandrixGaebNode;
  Amount: TLandrixXmlDecimal;
begin
  ABlocker := nil;
  if ACategory = nil then
    List := ABill.Root
  else
    List := ACategory.Children;
  for I := 0 to List.Count - 1 do
  begin
    N := List[I];
    if not (N.Kind in [gnkCategory, gnkItem, gnkMarkupItem]) then
      Continue;
    case StatusOf(N, AKinds) of
      gcsNotCounted:
        Continue;
      gcsUnknown:
        begin
          ABlocker := N;
          Exit;
        end;
    else
      if not Contribution(ABill, N, AKinds, Amount, ABlocker) then
        Exit;
      ASum := LandrixXmlDecimalAdd(ASum, Amount);
    end;
  end;
end;

function LandrixGaebComputeSum(ABill: TLandrixGaebBillOfQuantities; ACategory: TLandrixGaebCategory;
  AKinds: TLandrixGaebMatching): TLandrixGaebSum;
var
  Sum: TLandrixXmlDecimal;
begin
  if (AKinds <> nil) and (AKinds.Right <> ABill) then
    raise ELandrixGaebError.Create('the kinds must match the bill as right side');
  if (ACategory <> nil) and (ACategory.Bill <> ABill) then
    raise ELandrixGaebError.Create('the category is not part of the bill');
  Result.Value.Clear;
  Sum := LandrixXmlDecimalZero;
  ComputeInto(ABill, ACategory, AKinds, Sum, Result.Blocker);
  Result.Known := (Result.Blocker = nil) and ToGaebDecimal(Sum, Result.Value);
  if not Result.Known then
    Result.Value.Clear;
end;

function LandrixGaebApplyTotals(ABill: TLandrixGaebBillOfQuantities; AKinds: TLandrixGaebMatching): Integer;
var
  I: Integer;
  S: TLandrixGaebSum;
begin
  Result := 0;
  for I := 0 to ABill.NodeCount - 1 do
    if ABill.Nodes(I) is TLandrixGaebCategory then
    begin
      S := LandrixGaebComputeSum(ABill, TLandrixGaebCategory(ABill.Nodes(I)), AKinds);
      if S.Known then
        TLandrixGaebCategory(ABill.Nodes(I)).Totals.SetValue(gtfTotal, S.Value)
      else
        Inc(Result);
    end;
  S := LandrixGaebComputeSum(ABill, nil, AKinds);
  if S.Known then
    ABill.Totals.SetValue(gtfTotal, S.Value)
  else
    Inc(Result);
end;

{ Award }

procedure CopyTotals(AFrom, ATo: TLandrixGaebTotals);
var
  F: TLandrixGaebTotalField;
begin
  for F := Low(TLandrixGaebTotalField) to High(TLandrixGaebTotalField) do
    if AFrom.Value(F).HasValue then
      ATo.SetValue(F, AFrom.Value(F));
end;

{ An integer of the schema (MarkLbl, SubDNo) for comparison: white space,
  a plus sign and leading zeros do not count.
  DE: Eine Ganzzahl des Schemas (MarkLbl, SubDNo) zum Vergleich:
  Leerraum, Pluszeichen und fuehrende Nullen zaehlen nicht. }
function NumberKey(const S: TLandrixGaebString): TLandrixGaebString;
var
  T: TLandrixGaebString;
  Sign: TLandrixGaebString;
begin
  T := Trim(S);
  Sign := '';
  if (T <> '') and ((T[1] = '+') or (T[1] = '-')) then
  begin
    if T[1] = '-' then
      Sign := '-';
    T := Copy(T, 2, MaxInt);
  end;
  if not LandrixGaebIsDigits(T) then
    Result := S
  else
  begin
    Result := LandrixGaebStripZeros(T);
    if Result <> '' then
      Result := Sign + Result;
  end;
end;

{ The bidder's complements of AFrom into ATo (lists of
  TLandrixGaebTextComplement, not owned). }
procedure CopyComplements(AFrom, ATo: TObjectList);
var
  I, K: Integer;
  Src, Dst: TLandrixGaebTextComplement;
  Text: TLandrixGaebString;
begin
  for I := 0 to Integer(ATo.Count) - 1 do
  begin
    Dst := TLandrixGaebTextComplement(ATo[I]);
    if Dst.Kind <> gckBidder then
      Continue;
    Src := nil;
    for K := 0 to Integer(AFrom.Count) - 1 do
      if (TLandrixGaebTextComplement(AFrom[K]).Kind = gckBidder) and
        (NumberKey(TLandrixGaebTextComplement(AFrom[K]).MarkLbl) = NumberKey(Dst.MarkLbl)) then
      begin
        Src := TLandrixGaebTextComplement(AFrom[K]);
        Break;
      end;
    if (Src = nil) or Src.IsEmptyMarked then
      Continue;
    if Dst.WantsDecimal or Dst.WantsInteger then
    begin
      Text := '';
      if Src.SyntaxNode.HasComplBodyDec and Src.SyntaxNode.ComplBodyDec.Value.HasValue then
        Text := LandrixXmlUtf8ToWide(Src.SyntaxNode.ComplBodyDec.Value.Text)
      else if Src.SyntaxNode.HasComplBodyInt then
        Text := Trim(Src.SyntaxNode.ComplBodyInt.Value);
      if Text <> '' then
        Dst.SetBodyNumber(Text);
    end
    else
    begin
      Text := Src.BodyText;
      if Text <> '' then
        Dst.SetBodyText(Text);
    end;
  end;
end;

procedure NodeComplements(ANode: TLandrixGaebNode; AList: TObjectList);
var
  I: Integer;
begin
  for I := 0 to ANode.ComplementCount - 1 do
    AList.Add(ANode.Complements(I));
end;

procedure SubComplements(ASub: TLandrixGaebSubDescription; AList: TObjectList);
var
  I: Integer;
begin
  for I := 0 to ASub.ComplementCount - 1 do
    AList.Add(ASub.Complements(I));
end;

procedure CopyNodeComplements(AFrom, ATo: TLandrixGaebNode);
var
  A, B: TObjectList;
begin
  A := TObjectList.Create(False);
  B := TObjectList.Create(False);
  try
    NodeComplements(AFrom, A);
    NodeComplements(ATo, B);
    CopyComplements(A, B);
  finally
    B.Free;
    A.Free;
  end;
end;

procedure CopySubComplements(AFrom, ATo: TLandrixGaebSubDescription);
var
  A, B: TObjectList;
begin
  A := TObjectList.Create(False);
  B := TObjectList.Create(False);
  try
    SubComplements(AFrom, A);
    SubComplements(ATo, B);
    CopyComplements(A, B);
  finally
    B.Free;
    A.Free;
  end;
end;

procedure CopyItem(AFrom, ATo: TLandrixGaebItem);
var
  I, K, N: Integer;
  Src, Dst: TLandrixGaebSubDescription;
begin
  if AFrom.UP.HasValue then
    ATo.SetUP(AFrom.UP);
  for N := 1 to 6 do
    if AFrom.UPComp(N).HasValue then
      ATo.SetUPComp(N, AFrom.UPComp(N));
  if AFrom.DiscountPcnt.HasValue then
    ATo.SetDiscountPcnt(AFrom.DiscountPcnt);
  if AFrom.IT.HasValue then
    ATo.SetIT(AFrom.IT);
  if ATo.QtyTBD and AFrom.Qty.HasValue then
    ATo.SetQty(AFrom.Qty);
  for I := 0 to ATo.SubDescriptionCount - 1 do
  begin
    Dst := ATo.SubDescriptions(I);
    for K := 0 to AFrom.SubDescriptionCount - 1 do
    begin
      Src := AFrom.SubDescriptions(K);
      if NumberKey(Src.Number) <> NumberKey(Dst.Number) then
        Continue;
      if Src.UP.HasValue then
        Dst.SetUP(Src.UP);
      for N := 1 to 6 do
        if Src.UPComp(N).HasValue then
          Dst.SetUPComp(N, Src.UPComp(N));
      if Dst.QtyTBD and Src.Qty.HasValue then
        Dst.SetQty(Src.Qty);
      CopySubComplements(Src, Dst);
      Break;
    end;
  end;
  CopyNodeComplements(AFrom, ATo);
end;

procedure CopyMarkup(AFrom, ATo: TLandrixGaebMarkupItem);
begin
  if AFrom.MarkupPcnt.HasValue then
    ATo.SetMarkupPcnt(AFrom.MarkupPcnt);
  if AFrom.ITMarkup.HasValue then
    ATo.SetITMarkup(AFrom.ITMarkup);
  if AFrom.DiscountPcnt.HasValue then
    ATo.SetDiscountPcnt(AFrom.DiscountPcnt);
  if AFrom.IT.HasValue then
    ATo.SetIT(AFrom.IT);
  CopyNodeComplements(AFrom, ATo);
end;

procedure CopyParty(AFrom, ATo: TLandrixGaebParty);
begin
  if not AFrom.Exists then
    Exit;
  if AFrom.Name1 <> '' then ATo.Name1 := AFrom.Name1;
  if AFrom.Name2 <> '' then ATo.Name2 := AFrom.Name2;
  if AFrom.Name3 <> '' then ATo.Name3 := AFrom.Name3;
  if AFrom.Name4 <> '' then ATo.Name4 := AFrom.Name4;
  if AFrom.Street <> '' then ATo.Street := AFrom.Street;
  if AFrom.PCode <> '' then ATo.PCode := AFrom.PCode;
  if AFrom.City <> '' then ATo.City := AFrom.City;
  if AFrom.Country <> '' then ATo.Country := AFrom.Country;
  if AFrom.Contact <> '' then ATo.Contact := AFrom.Contact;
  if AFrom.Phone <> '' then ATo.Phone := AFrom.Phone;
  if AFrom.Fax <> '' then ATo.Fax := AFrom.Fax;
  if AFrom.Email <> '' then ATo.Email := AFrom.Email;
  if AFrom.VATID <> '' then ATo.VATID := AFrom.VATID;
end;

procedure Warn(ADiagnostics: TLandrixGaebDiagnostics; const ARuleId: string; ANode: TLandrixGaebNode;
  const AMessage: string);
begin
  if ADiagnostics <> nil then
    ADiagnostics.AddAt(ARuleId, gsWarning, ANode.Path, 0, 0, -1, AMessage);
end;

{ The request as an X86 document: written for the award and read back. }
function CopyAsAward(ARequest: TLandrixGaebBillOfQuantities;
  ADiagnostics: TLandrixGaebDiagnostics): TLandrixGaebBillOfQuantities;
var
  Own: TLandrixGaebDiagnostics;
  Options: TLandrixGaebXmlWriteOptions;
  Buffer: TLandrixXmlUtf8;
  Errors, Warnings: Integer;
  I: TLandrixGaebListIndex;
  D: TLandrixGaebDiagnostic;
  Doc: TLandrixGaebXmlGAEB;
  Det: TLandrixGaebDetection;
begin
  Own := TLandrixGaebDiagnostics.Create;
  try
    Options := LandrixGaebXmlDefaultWriteOptions;
    Options.Check := False;
    Options.Indent := False;
    Buffer := LandrixGaebXmlWriteCollect(ARequest.Document,
      LandrixGaebTarget(ARequest.Target.Version, ARequest.Target.Edition, gp86), Options, Own, Errors, Warnings);
    Doc := LandrixGaebXmlReadBuffer(Pointer(Buffer), Integer(Length(Buffer)), Own, Det);
    { the bill owns the document from here on, also if its constructor
      fails }
    Result := TLandrixGaebBillOfQuantities.Create(Doc, Det.Target, True);
    try
      { the replaced DP is the purpose of the copy }
      if ADiagnostics <> nil then
        for I := 0 to Own.Count - 1 do
        begin
          D := Own[I];
          if D.RuleId <> 'GAEB-WRT-003' then
            ADiagnostics.AddAt(D.RuleId, D.Severity, D.Path, D.Line, D.Column, D.Offset, D.Message);
        end;
    except
      Result.Free;
      raise;
    end;
  finally
    Own.Free;
  end;
end;

function LandrixGaebBuildAward(ARequest, ABid: TLandrixGaebBillOfQuantities;
  ADiagnostics: TLandrixGaebDiagnostics): TLandrixGaebBillOfQuantities;
var
  Matching: TLandrixGaebMatching;
  I: Integer;
  M: TLandrixGaebMatch;
begin
  if ARequest.Target.Phase <> gp83 then
    raise ELandrixGaebError.Create('the request of an award must be an X83');
  if ABid.Target.Phase <> gp84 then
    raise ELandrixGaebError.Create('the bid of an award must be an X84');
  Result := CopyAsAward(ARequest, ADiagnostics);
  try
    Matching := TLandrixGaebMatching.Create(Result, ABid);
    try
      for I := 0 to Matching.Count - 1 do
      begin
        M := Matching.Entries(I);
        case M.Kind of
          gmkPair:
            if M.Left.Kind <> M.Right.Kind then
              Warn(ADiagnostics, 'GAEB-PRC-003', M.Right,
                'item and markup item with the same OZ in request and bid; nothing taken over')
            else if M.Left is TLandrixGaebItem then
              CopyItem(TLandrixGaebItem(M.Right), TLandrixGaebItem(M.Left))
            else if M.Left is TLandrixGaebMarkupItem then
              CopyMarkup(TLandrixGaebMarkupItem(M.Right), TLandrixGaebMarkupItem(M.Left))
            else
              CopyTotals(TLandrixGaebCategory(M.Right).Totals, TLandrixGaebCategory(M.Left).Totals);
          gmkOnlyRight:
            Warn(ADiagnostics, 'GAEB-PRC-001', M.Right, 'element of the bid not in the request; nothing taken over');
          gmkAmbiguous:
            if M.Right <> nil then
              Warn(ADiagnostics, 'GAEB-PRC-002', M.Right, 'OZ ambiguous in request or bid; nothing taken over');
        else
          { only in the request: stays without prices }
        end;
      end;
    finally
      Matching.Free;
    end;
    CopyTotals(ABid.Totals, Result.Totals);
    CopyParty(ABid.Contractor, Result.Contractor);
    for I := 0 to Result.NodeCount - 1 do
      if (Result.Nodes(I) is TLandrixGaebMarkupItem) and
        (not TLandrixGaebMarkupItem(Result.Nodes(I)).MarkupPcnt.HasValue or
        not TLandrixGaebMarkupItem(Result.Nodes(I)).ITMarkup.HasValue) then
        Warn(ADiagnostics, 'GAEB-PRC-004', Result.Nodes(I), 'markup item without Markup or ITMarkup');
  except
    Result.Free;
    raise;
  end;
end;

end.
