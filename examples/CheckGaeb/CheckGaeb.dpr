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
     X83 and bid X84),
  4. with -xsd=<folder>, the validation against the original GAEB schemas
     in that folder (LandrixGaebXmlXsd; tools/fetch-gaeb-xsd.ps1 downloads
     them).
  Exit code 0 if no stage found an error, 1 otherwise.

  Usage: CheckGaeb [-xsd=<folder>] <file> [<second file>] }

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
  LandrixGaebXmlXsd,
  LandrixGaebRules;

var
  { the arguments without -xsd=; the schema folder, '' without }
  Files: array of string;
  XsdFolder: string;

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

{ Stages 1, 2 and 4 for one file; the document read for stage 3 is
  returned. }
function CheckFile(const AFileName: string; ADiagnostics: TLandrixGaebDiagnostics;
  ASchemas: TLandrixGaebXmlXsdSchemas; out ATarget: TLandrixGaebTarget): TLandrixGaebXmlGAEB;
var
  Det: TLandrixGaebDetection;
  Ok: Boolean;
begin
  Ok := LandrixGaebXmlCheckFile(AFileName, ADiagnostics, 0, Det);
  WriteLn(AFileName, ': GAEB DA XML ', TargetText(Det.Target));
  WriteLn('  content model check: ', Passed(Ok));
  if ASchemas <> nil then
    WriteLn('  XSD validation: ', Passed(LandrixGaebXmlXsdValidateFile(ASchemas, AFileName, ADiagnostics, 0,
      Det)));
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
  Schemas: TLandrixGaebXmlXsdSchemas;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  First := nil;
  Second := nil;
  Schemas := nil;
  try
    try
      if XsdFolder <> '' then
        Schemas := TLandrixGaebXmlXsdSchemas.Create(XsdFolder);
      First := CheckFile(Files[0], Diags, Schemas, FirstTarget);
      if Length(Files) = 2 then
      begin
        Second := CheckFile(Files[1], Diags, Schemas, SecondTarget);
        WriteLn('pair rules: ', Passed(LandrixGaebCheckPair(First, FirstTarget, Second, SecondTarget,
          Diags)));
      end;
    finally
      Schemas.Free;
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

procedure ReadArguments;
var
  I: Integer;
begin
  XsdFolder := '';
  SetLength(Files, 0);
  for I := 1 to ParamCount do
    if Copy(ParamStr(I), 1, 5) = '-xsd=' then
      XsdFolder := Copy(ParamStr(I), 6, MaxInt)
    else
    begin
      SetLength(Files, Length(Files) + 1);
      Files[High(Files)] := ParamStr(I);
    end;
end;

begin
  ReadArguments;
  if (Length(Files) < 1) or (Length(Files) > 2) then
  begin
    WriteLn('Usage: CheckGaeb [-xsd=<folder>] <file> [<second file>]');
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
