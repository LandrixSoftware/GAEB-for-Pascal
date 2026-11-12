{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Checks GAEB DA XML files in three stages and prints every finding:
  1. the content model check against the schema of the target the file
     declares (LandrixGaebXmlCheck),
  2. the business rules of its phase (LandrixGaebRules),
  3. with a second file, the pair rules between both (for example request
     X83 and bid X84).
  Exit code 0 if no stage found an error, 1 otherwise.

  Usage: CheckGaeb <file> [<second file>] }

program CheckGaeb;

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
  LandrixGaebDetect,
  LandrixGaebXmlModel,
  LandrixGaebXmlReader,
  LandrixGaebXmlCheck,
  LandrixGaebRules;

function Passed(AOk: Boolean): string;
begin
  if AOk then
    Result := 'passed'
  else
    Result := 'errors found';
end;

function TargetText(const ATarget: TLandrixGaebTarget): string;
begin
  Result := LandrixXmlUtf8ToString(LandrixGaebVersionToText(ATarget.Version)) + ' DA' +
    LandrixXmlUtf8ToString(LandrixGaebPhaseToDP(ATarget.Phase));
end;

{ Stages 1 and 2 for one file; the document read for stage 3 is returned. }
function CheckFile(const AFileName: string; ADiagnostics: TLandrixGaebDiagnostics;
  out ATarget: TLandrixGaebTarget): TLandrixGaebXmlGAEB;
var
  Det: TLandrixGaebDetection;
  Ok: Boolean;
begin
  Ok := LandrixGaebXmlCheckFile(AFileName, ADiagnostics, 0, Det);
  WriteLn(AFileName, ': GAEB DA XML ', TargetText(Det.Target));
  WriteLn('  content model check: ', Passed(Ok));
  Result := LandrixGaebXmlReadFile(AFileName, ADiagnostics, 0, Det);
  try
    ATarget := Det.Target;
    WriteLn('  business rules (rule set ', LandrixGaebRuleSetVersion, '): ',
      Passed(LandrixGaebCheckRules(Result, ATarget, ADiagnostics)));
  except
    Result.Free;
    raise;
  end;
end;

procedure Run;
var
  Diags: TLandrixGaebDiagnostics;
  First, Second: TLandrixGaebXmlGAEB;
  FirstTarget, SecondTarget: TLandrixGaebTarget;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  First := nil;
  Second := nil;
  try
    try
      First := CheckFile(ParamStr(1), Diags, FirstTarget);
      if ParamCount = 2 then
      begin
        Second := CheckFile(ParamStr(2), Diags, SecondTarget);
        WriteLn('pair rules: ', Passed(LandrixGaebCheckPair(First, FirstTarget, Second, SecondTarget,
          Diags)));
      end;
    finally
      Second.Free;
      First.Free;
      { the findings of all stages, also when one of them failed; each names
        its rule, e.g. GAEB-CHK-002 or GAEB-BR-OZ-001, and the path of the
        element }
      Write(Diags.ToText);
      WriteLn(Diags.Count, ' finding(s)');
    end;
    if Diags.HasErrors then
      ExitCode := 1;
  finally
    Diags.Free;
  end;
end;

begin
  if (ParamCount < 1) or (ParamCount > 2) then
  begin
    WriteLn('Usage: CheckGaeb <file> [<second file>]');
    ExitCode := 2;
    Exit;
  end;
  try
    Run;
  except
    on E: Exception do
    begin
      WriteLn(E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
