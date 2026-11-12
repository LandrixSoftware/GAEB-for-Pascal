{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Reads a GAEB DA XML file and prints its bill of quantities as a tree:
  ordinal number (OZ), short text, quantity, unit, unit price and total of
  every item, the label of every category, and the total of the bill.

  Usage: ReadBoQ <file> }

program ReadBoQ;

{$I LandrixGaeb.inc}

{$IFDEF MSWINDOWS}
  {$APPTYPE CONSOLE}
{$ENDIF}

uses
{$IFDEF FPC}
  {$IFDEF UNIX}
  { converts between UTF-8 and the native string on Unix (output of texts) }
  cwstring,
  {$ENDIF}
{$ENDIF}
  SysUtils,
  LandrixXmlBase,
  LandrixGaebTypes,
  LandrixGaebDiagnostics,
  LandrixGaebBoQ;

{ Texts of the library are UTF-16; the console takes the native string. }
function S(const AText: TLandrixGaebString): string;
begin
  Result := LandrixXmlUtf8ToString(LandrixXmlWideToUtf8(AText));
end;

{ A decimal as written in the document, '-' if absent. }
function D(const AValue: TLandrixGaebDecimal): string;
begin
  if AValue.HasValue then
    Result := LandrixXmlUtf8ToString(AValue.Text)
  else
    Result := '-';
end;

procedure PrintNode(ANode: TLandrixGaebNode; const AIndent: string);
var
  I: Integer;
  Item: TLandrixGaebItem;
begin
  { by class, so that a kind of node a later release adds lands in the last
    branch }
  if ANode is TLandrixGaebCategory then
  begin
    WriteLn(AIndent, S(ANode.OZ), '  ', S(TLandrixGaebCategory(ANode).Lbl),
      '  total ', D(TLandrixGaebCategory(ANode).Total));
    for I := 0 to TLandrixGaebCategory(ANode).Children.Count - 1 do
      PrintNode(TLandrixGaebCategory(ANode).Children[I], AIndent + '  ');
  end
  else if ANode is TLandrixGaebItem then
  begin
    Item := TLandrixGaebItem(ANode);
    WriteLn(AIndent, S(Item.OZ), '  ', S(Item.ShortText));
    WriteLn(AIndent, '      ', D(Item.Qty), ' ', S(Item.QU), ' x ', D(Item.UP), ' = ', D(Item.IT));
  end
  else if ANode is TLandrixGaebMarkupItem then
    WriteLn(AIndent, S(ANode.OZ), '  ', S(ANode.ShortText), '  markup item, total ',
      D(TLandrixGaebMarkupItem(ANode).IT))
  else if ANode is TLandrixGaebRemark then
    WriteLn(AIndent, 'remark: ', S(ANode.ShortText))
  else if ANode is TLandrixGaebPerfDescr then
    WriteLn(AIndent, 'execution description ', S(TLandrixGaebPerfDescr(ANode).PerfNo))
  else
    WriteLn(AIndent, 'other node');
end;

procedure Run(const AFileName: string);
var
  Bill: TLandrixGaebBillOfQuantities;
  Diags: TLandrixGaebDiagnostics;
  I: Integer;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  try
    Bill := TLandrixGaebBillOfQuantities.LoadFromFile(AFileName, Diags, 0);
    try
      WriteLn('GAEB DA XML ', LandrixXmlUtf8ToString(LandrixGaebVersionToText(Bill.Target.Version)),
        ', DA', LandrixXmlUtf8ToString(LandrixGaebPhaseToDP(Bill.Target.Phase)));
      WriteLn('project: ', S(Bill.ProjectName), ', bill: ', S(Bill.BoQName), ', currency: ', S(Bill.Currency));
      for I := 0 to Bill.Root.Count - 1 do
        PrintNode(Bill.Root[I], '');
      WriteLn('total of the bill: ', D(Bill.Total));
    finally
      Bill.Free;
    end;
  finally
    { findings of reading, e.g. elements the target does not know; also
      when reading failed }
    Write(Diags.ToText);
    Diags.Free;
  end;
end;

begin
  if ParamCount <> 1 then
  begin
    WriteLn('Usage: ReadBoQ <file>');
    ExitCode := 2;
    Exit;
  end;
  try
    Run(ParamStr(1));
  except
    on E: Exception do
    begin
      WriteLn(E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
