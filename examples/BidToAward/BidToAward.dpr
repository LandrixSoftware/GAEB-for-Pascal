{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ The bid process on the business facade: matches a request (X83) with a
  bid (X84) by ordinal number, computes the total of the bid with the kinds
  of items of the request (a bid does not carry them), builds the award
  (X86) from both and writes it.

  Usage: BidToAward <request.x83> <bid.x84> <award.x86> }

program BidToAward;

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
  LandrixGaebBoQ,
  LandrixGaebProcess;

function S(const AText: TLandrixGaebString): string;
begin
  Result := LandrixXmlUtf8ToString(LandrixXmlWideToUtf8(AText));
end;

function D(const AValue: TLandrixGaebDecimal): string;
begin
  if AValue.HasValue then
    Result := LandrixXmlUtf8ToString(AValue.Text)
  else
    Result := '-';
end;

procedure Run(const ARequest, ABid, AAward: string);
var
  Request, Bid, Award: TLandrixGaebBillOfQuantities;
  Matching: TLandrixGaebMatching;
  Sum: TLandrixGaebSum;
  Diags: TLandrixGaebDiagnostics;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  Request := nil;
  Bid := nil;
  Award := nil;
  Matching := nil;
  try
    Request := TLandrixGaebBillOfQuantities.LoadFromFile(ARequest, Diags, 0);
    Bid := TLandrixGaebBillOfQuantities.LoadFromFile(ABid, Diags, 0);

    { request left, bid right: every node of the bid finds its partner }
    Matching := TLandrixGaebMatching.Create(Request, Bid);
    WriteLn('matched: ', Matching.CountOf(gmkPair), ' pair(s), ', Matching.CountOf(gmkOnlyLeft),
      ' only in the request, ', Matching.CountOf(gmkOnlyRight), ' only in the bid, ',
      Matching.CountOf(gmkAmbiguous), ' ambiguous');

    { the bid alone does not tell which items count (alternatives,
      eventual items); the kinds come from the request }
    Sum := LandrixGaebComputeSum(Bid, nil, Matching);
    if Sum.Known then
      WriteLn('total of the bid: ', D(Sum.Value), ' (stated: ', D(Bid.Total), ')')
    else if Sum.Blocker <> nil then
      WriteLn('total of the bid unknown, blocked by ', S(Sum.Blocker.Path))
    else
      WriteLn('total of the bid too large');

    Award := LandrixGaebBuildAward(Request, Bid, Diags);
    { the request names no owner; an award needs one with an address }
    Award.Owner.Name1 := 'Example owner';
    Award.Owner.Street := 'Example street 1';
    Award.Owner.PCode := '12345';
    Award.Owner.City := 'Example town';
    Award.SaveToFile(AAward, Diags);
    WriteLn('award written: ', AAward, ', contractor ', S(Award.Contractor.Name1), ', total ', D(Award.Total));
  finally
    { findings of reading, building and writing, also after a failure }
    Write(Diags.ToText);
    Matching.Free;
    Award.Free;
    Bid.Free;
    Request.Free;
    Diags.Free;
  end;
end;

begin
  if ParamCount <> 3 then
  begin
    WriteLn('Usage: BidToAward <request.x83> <bid.x84> <award.x86>');
    ExitCode := 2;
    Exit;
  end;
  try
    Run(ParamStr(1), ParamStr(2), ParamStr(3));
  except
    on E: Exception do
    begin
      WriteLn(E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
