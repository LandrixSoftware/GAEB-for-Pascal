{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ The bidder's side: turns a request (X83, or a GAEB 90 / GAEB DA 2000
  request) into a bid (X84). It enters a unit price for every item and
  computes the total of the item (quantity x unit price, rounded to cents;
  the bid itself carries no quantity of the request),
  fills the bidder's text complements, names the bidder, computes the
  totals of the categories and of the bill and saves the bid. The unit
  price here is a fixed example value; a real program takes it from its
  own calculation.

  DE: Die Seite des Bieters: macht aus einer Anfrage (X83 oder eine
  Anfrage in GAEB 90 / GAEB DA 2000) ein Angebot (X84). Es traegt fuer
  jede Position einen Einheitspreis ein und berechnet den Gesamtbetrag
  der Position (Menge x Einheitspreis, auf Cent gerundet; das Angebot
  selbst traegt keine Menge der Anfrage), fuellt die
  Ergaenzungen des Bieters, nennt den Bieter, berechnet die Summen der
  Bereiche und des LV und speichert das Angebot. Der Einheitspreis ist
  hier ein fester Beispielwert; ein echtes Programm nimmt ihn aus seiner
  eigenen Kalkulation.

  Usage / Aufruf: CreateBid <request> <bid.x84> }

program CreateBid;

{$I LandrixGaeb.inc}

{$IFDEF MSWINDOWS}
  {$APPTYPE CONSOLE}
{$ENDIF}

uses
{$IFDEF FPC}
  {$IFDEF UNIX}
  { converts between UTF-8 and the native string on Unix (output of texts)
    DE: wandelt unter Unix zwischen UTF-8 und dem nativen String (Ausgabe
    von Texten) }
  cwstring,
  {$ENDIF}
{$ENDIF}
  SysUtils,
  LandrixXmlBase,
  LandrixXmlDecimal,
  LandrixGaebTypes,
  LandrixGaebDiagnostics,
  LandrixGaebBoQ,
  LandrixGaebProcess;

{ A decimal as written in the document, '-' if absent.
  DE: Eine Dezimalzahl wie im Dokument, '-' wenn sie fehlt. }
function D(const AValue: TLandrixGaebDecimal): string;
begin
  if AValue.HasValue then
    Result := LandrixXmlUtf8ToString(AValue.Text)
  else
    Result := '-';
end;

{ A decimal from its text ('12.50'); never from a Double, which cannot
  hold every decimal exactly.
  DE: Eine Dezimalzahl aus ihrem Text ('12.50'); nie aus einem Double,
  das nicht jede Dezimalzahl genau darstellen kann. }
function Dec(const AText: string): TLandrixGaebDecimal;
begin
  Result.Clear;
  if not Result.TrySetText(LandrixXmlStringToUtf8(AText)) then
    raise Exception.Create('not a decimal: ' + AText);
end;

{ Total of an item: quantity x unit price, rounded commercially to cents
  (half away from zero), exactly in decimal arithmetic.
  DE: Gesamtbetrag einer Position: Menge x Einheitspreis, kaufmaennisch
  auf Cent gerundet (halb weg von null), exakt in Dezimalarithmetik. }
function ItemTotal(const AQty, AUP: TLandrixGaebDecimal): TLandrixGaebDecimal;
begin
  Result.Clear;
  Result.TrySetText(LandrixXmlFormatDecimal(LandrixGaebRoundHalfAwayFromZero(
    LandrixXmlDecimalMultiply(AQty.AsXmlDecimal, AUP.AsXmlDecimal), 2)));
end;

{ Fills a text complement of the bidder, for example the product offered;
  True if it was one.
  DE: Fuellt eine Ergaenzung des Bieters, etwa das angebotene Fabrikat;
  True, wenn es eine war. }
function FillComplement(C: TLandrixGaebTextComplement): Boolean;
begin
  Result := C.Kind = gckBidder;
  if not Result then
    Exit;
  if C.WantsDecimal or C.WantsInteger then
    C.SetBodyNumber('1')
  else
    C.SetBodyText('Example product');
end;

procedure Run(const ARequest, ABid: string);
var
  Bill: TLandrixGaebBillOfQuantities;
  Diags: TLandrixGaebDiagnostics;
  T: TLandrixGaebTarget;
  Options: TLandrixGaebXmlWriteOptions;
  Item: TLandrixGaebItem;
  Sub: TLandrixGaebSubDescription;
  I, J, K, Priced, Filled, Markups, Open: Integer;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  Bill := nil;
  try
    { any format the library reads: GAEB DA XML, GAEB DA 2000, GAEB 90
      DE: jedes Format, das die Bibliothek liest }
    Bill := TLandrixGaebBillOfQuantities.LoadFromFile(ARequest, Diags, 0);
    if Bill.Target.Phase <> gp83 then
      raise Exception.Create('the input is no request (X83)');

    { the document stays a request (Target); it is saved as a bid
      (OutputTarget), which converts on saving. OutputTarget, not Target,
      is the base: for GAEB DA XML 3.0/3.1, which is read only, it is
      already 3.3
      DE: das Dokument bleibt eine Anfrage (Target); gespeichert wird es
      als Angebot (OutputTarget), das wandelt beim Speichern. Grundlage ist
      OutputTarget, nicht Target: fuer GAEB DA XML 3.0/3.1, das nur gelesen
      wird, ist es schon 3.3 }
    T := Bill.OutputTarget;
    T.Phase := gp84;
    Bill.OutputTarget := T;
    { a bid carries prices, not the texts, units and labels of the request:
      the default mode (strict) refuses to drop them, gwmBestEffort leaves
      them out and reports each one (GAEB-WRT-001)
      DE: ein Angebot traegt Preise, nicht die Texte, Einheiten und
      Bezeichnungen der Anfrage: der Standardmodus (streng) verweigert das
      Weglassen, gwmBestEffort laesst sie weg und meldet jedes
      (GAEB-WRT-001) }
    Options := Bill.WriteOptions;
    Options.Mode := gwmBestEffort;
    Bill.WriteOptions := Options;

    { the bidder / DE: der Bieter }
    Bill.Contractor.Name1 := 'Example builder Ltd';
    Bill.Contractor.Street := 'Example street 2';
    Bill.Contractor.PCode := '12345';
    Bill.Contractor.City := 'Example town';

    Priced := 0;
    Filled := 0;
    Markups := 0;
    for I := 0 to Bill.AllItems.Count - 1 do
    begin
      { AllItems holds items and markup items; a markup item takes its
        amount from the items it refers to, which this example does not
        compute (see below)
        DE: AllItems enthaelt Positionen und Zuschlagspositionen; eine
        Zuschlagsposition nimmt ihren Betrag aus den Positionen, auf die sie
        sich bezieht, was dieses Beispiel nicht berechnet (siehe unten) }
      if not (Bill.AllItems[I] is TLandrixGaebItem) then
      begin
        Inc(Markups);
        Continue;
      end;
      Item := TLandrixGaebItem(Bill.AllItems[I]);
      { a bid states a quantity only where the request leaves it open
        (QtyTBD); all other quantities stay with the request, also those of
        items that do not apply
        DE: ein Angebot nennt eine Menge nur, wo die Anfrage sie offen
        laesst (QtyTBD); alle anderen Mengen bleiben bei der Anfrage, auch
        die entfallender Positionen }
      if Item.QtyTBD then
        { the bidder enters the quantity; 1 is an example value
          DE: der Bieter traegt die Menge ein; 1 ist ein Beispielwert }
        Item.SetQty(Dec('1.000'));
      { the same rule for the quantities of its sub descriptions
        DE: dieselbe Regel fuer die Mengen seiner Unterbeschreibungen }
      for J := 0 to Item.SubDescriptionCount - 1 do
      begin
        Sub := Item.SubDescriptions(J);
        if Sub.QtyTBD and not Item.NotApplicable then
          Sub.SetQty(Dec('1.000'))
        else
          Sub.ClearQty;
      end;
      if Item.NotApplicable then
      begin
        Item.ClearQty;
        Continue;
      end;
      Item.SetUP(Dec('12.50'));
      { the total: quantity x unit price; a lump sum item without a
        quantity counts once
        DE: der Gesamtbetrag: Menge x Einheitspreis; eine Pauschalposition
        ohne Menge zaehlt einmal }
      if Item.Qty.HasValue then
        Item.SetIT(ItemTotal(Item.Qty, Item.UP))
      else if Item.IsLumpSum then
        Item.SetIT(ItemTotal(Dec('1'), Item.UP));
      if not Item.QtyTBD then
        Item.ClearQty;
      Inc(Priced);
      { the bidder's text complements, also those in sub descriptions
        DE: die Ergaenzungen des Bieters, auch die in Unterbeschreibungen }
      for K := 0 to Item.ComplementCount - 1 do
        if FillComplement(Item.Complements(K)) then
          Inc(Filled);
      for J := 0 to Item.SubDescriptionCount - 1 do
      begin
        Sub := Item.SubDescriptions(J);
        for K := 0 to Sub.ComplementCount - 1 do
          if FillComplement(Sub.Complements(K)) then
            Inc(Filled);
      end;
    end;

    { totals of the categories and of the bill from the item totals; the
      document is a request, so the kinds of its items (alternatives,
      eventual items) are known and decide what counts
      DE: Summen der Bereiche und des LV aus den Gesamtbetraegen; das
      Dokument ist eine Anfrage, die Arten seiner Positionen
      (Alternativen, Bedarfspositionen) sind also bekannt und entscheiden,
      was zaehlt }
    Open := LandrixGaebApplyTotals(Bill, nil);
    { a markup item without its amount leaves the totals that contain it
      open; a real program computes markup items before this step
      DE: eine Zuschlagsposition ohne Betrag laesst die Summen offen, die
      sie enthalten; ein echtes Programm berechnet Zuschlagspositionen vor
      diesem Schritt }
    if Open > 0 then
      WriteLn('warning: ', Open, ' total(s) not computed (', Markups,
        ' markup item(s) without amount, or items without total)');

    Bill.SaveToFile(ABid, Diags);
    WriteLn('bid written: ', ABid, ', ', Priced, ' item(s) priced, ', Filled,
      ' complement(s) filled, total ', D(Bill.Total), ', ', Open, ' total(s) not computed, ',
      Diags.CountOf('GAEB-WRT-001'), ' element(s) of the request left out');
  finally
    { other findings of reading and writing, also after a failure
      DE: andere Befunde von Lesen und Schreiben, auch nach einem Fehler }
    for I := 0 to Integer(Diags.Count) - 1 do
      if Diags[I].RuleId <> 'GAEB-WRT-001' then
        WriteLn(Diags[I].RuleId, ': ', Diags[I].Message);
    Bill.Free;
    Diags.Free;
  end;
end;

begin
  if ParamCount <> 2 then
  begin
    WriteLn('Usage: CreateBid <request> <bid.x84>');
    ExitCode := 2;
    Exit;
  end;
  try
    Run(ParamStr(1), ParamStr(2));
  except
    on E: Exception do
    begin
      WriteLn(E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
