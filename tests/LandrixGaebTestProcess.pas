{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ The bid process X81 -> X83 -> X84 -> X86 on one synthetic project
  (tests/data/process): every document reads, checks and writes without a
  finding, the request X81 written as X83 is the X83, and the pair rules
  find nothing between request, bid and award (and do find a changed
  price). Building the award from request and bid is a task of the business
  facade (phase 4); here the award is a document of its own. }

unit LandrixGaebTestProcess;

{$I LandrixGaeb.inc}

interface

procedure Register;

implementation

uses
  SysUtils,
  Classes,
  LandrixXmlBase,
  LandrixGaebTypes,
  LandrixGaebDiagnostics,
  LandrixGaebDetect,
  LandrixGaebXmlModel,
  LandrixGaebXmlReader,
  LandrixGaebXmlWriteBase,
  LandrixGaebXmlWriter,
  LandrixGaebXmlCheck,
  LandrixGaebRules,
  LandrixGaebTestXmlCompare,
  LandrixGaebTestNoValues,
  LandrixGaebTestFramework;

const
  Names: array[0..3] of string = ('request.x81', 'request.x83', 'bid.x84', 'award.x86');
  Phases: array[0..3] of TLandrixGaebPhase = (gp81, gp83, gp84, gp86);

function ProcessFile(const AName: string): TLandrixXmlUtf8;
begin
  Result := ReadFileBytes(RepositoryRoot + 'tests' + PathDelim + 'data' + PathDelim + 'process' + PathDelim + AName);
end;

function ReplaceAll(const S, APart, AWith: TLandrixXmlUtf8): TLandrixXmlUtf8;
var
  Rest: TLandrixXmlUtf8;
  P: Integer;
begin
  Result := '';
  Rest := S;
  P := Pos(APart, Rest);
  while P > 0 do
  begin
    Result := Result + Copy(Rest, 1, P - 1) + AWith;
    Rest := Copy(Rest, P + Integer(Length(APart)), MaxInt);
    P := Pos(APart, Rest);
  end;
  Result := Result + Rest;
end;

function RuleIds(ADiags: TLandrixGaebDiagnostics): string;
var
  I: TLandrixGaebListIndex;
begin
  Result := '';
  for I := 0 to ADiags.Count - 1 do
    Result := Result + ' ' + ADiags[I].RuleId;
end;

function Strict: TLandrixGaebXmlWriteOptions;
begin
  Result := LandrixGaebXmlDefaultWriteOptions;
  Result.Mode := gwmStrict;
end;

{ Reads a document of the process; the reader, the check and the rules add
  nothing, and it writes in strict mode for its own target. }
function Load(const ASource: TLandrixXmlUtf8; const AName: string; APhase: TLandrixGaebPhase;
  out ATarget: TLandrixGaebTarget): TLandrixGaebXmlGAEB;
var
  Diags: TLandrixGaebDiagnostics;
  Det: TLandrixGaebDetection;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  Result := nil;
  try
    Result := LandrixGaebXmlReadBuffer(Pointer(ASource), Integer(Length(ASource)), Diags, Det);
    ATarget := Det.Target;
    Check(Det.Target.Phase = APhase, AName + ': phase');
    CheckEquals(0, Integer(Diags.Count), AName + ': read without diagnostics:' + RuleIds(Diags));
    Diags.Clear;
    Check(LandrixGaebXmlCheckBuffer(Pointer(ASource), Integer(Length(ASource)), Diags, Det),
      AName + ': the check accepts it');
    CheckEquals(0, Integer(Diags.Count), AName + ': check without diagnostics:' + RuleIds(Diags));
    Diags.Clear;
    LandrixGaebCheckRules(Result, ATarget, Diags);
    CheckEquals(0, Integer(Diags.Count), AName + ': rules without finding:' + RuleIds(Diags));
    Diags.Clear;
    LandrixGaebXmlWriteUtf8(Result, ATarget, Strict, Diags);
    CheckEquals(0, Integer(Diags.Count), AName + ': written without diagnostics:' + RuleIds(Diags));
  except
    Result.Free;
    Diags.Free;
    raise;
  end;
  Diags.Free;
end;

procedure TestChain;
var
  Docs: array[0..3] of TLandrixGaebXmlGAEB;
  Targets: array[0..3] of TLandrixGaebTarget;
  Diags: TLandrixGaebDiagnostics;
  Diffs: TStringList;
  Converted, Changed: TLandrixGaebXmlGAEB;
  ConvertedTarget, ChangedTarget: TLandrixGaebTarget;
  Output: TLandrixXmlUtf8;
  I: Integer;
begin
  for I := 0 to 3 do
    Docs[I] := nil;
  Converted := nil;
  Changed := nil;
  Diags := TLandrixGaebDiagnostics.Create;
  Diffs := TStringList.Create;
  try
    for I := 0 to 3 do
      Docs[I] := Load(ProcessFile(Names[I]), Names[I], Phases[I], Targets[I]);

    { X81 -> X83: the request for bids is the description of the work with
      another DP; nothing is lost, the writer only reports the new DP }
    Output := LandrixGaebXmlWriteUtf8(Docs[0], LandrixGaebTarget(Targets[0].Version, Targets[0].Edition, gp83),
      Strict, Diags);
    CheckEqualsStr(' GAEB-WRT-003', RuleIds(Diags), 'request.x81 written as X83: only the DP is replaced');
    Converted := Load(Output, 'request.x81 as X83', gp83, ConvertedTarget);
    CompareGaebModels(Docs[1], Converted, Diffs);
    CheckEqualsStr('/GAEB/GAEBInfo/Date', Trim(Diffs.Text), 'request.x81 as X83 is request.x83 but for the date');

    { X83 -> X84 and X84 -> X86: the pair rules find nothing }
    Diags.Clear;
    Check(LandrixGaebCheckPair(Docs[1], Targets[1], Docs[2], Targets[2], Diags), 'request -> bid: no error');
    CheckEquals(0, Integer(Diags.Count), 'request -> bid: no finding:' + RuleIds(Diags));
    Diags.Clear;
    Check(LandrixGaebCheckPair(Docs[2], Targets[2], Docs[3], Targets[3], Diags), 'bid -> award: no error');
    CheckEquals(0, Integer(Diags.Count), 'bid -> award: no finding:' + RuleIds(Diags));

    { an award with another price of the alternative (not in the totals):
      the award itself stays consistent, the pair rule finds the change }
    Output := ReplaceAll(ReplaceAll(ProcessFile('award.x86'), '<UP>12.00</UP>', '<UP>13.00</UP>'),
      '<IT>48.00</IT>', '<IT>52.00</IT>');
    Changed := Load(Output, 'award.x86 changed', gp86, ChangedTarget);
    Diags.Clear;
    Check(LandrixGaebCheckPair(Docs[2], Targets[2], Changed, ChangedTarget, Diags),
      'bid -> changed award: a warning, no error');
    CheckEqualsStr(' GAEB-BR-PAIR-84-86-002', RuleIds(Diags), 'bid -> changed award: the unit price');
    if Diags.Count = 1 then
      Check(Diags[0].Severity = gsWarning, 'bid -> changed award: severity warning');
  finally
    Changed.Free;
    Converted.Free;
    for I := 0 to 3 do
      Docs[I].Free;
    Diffs.Free;
    Diags.Free;
  end;
end;

procedure Register;
begin
  RegisterTest('Process.Chain', TestChain);
end;

end.
