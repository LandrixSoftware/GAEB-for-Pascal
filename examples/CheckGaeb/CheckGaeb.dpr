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

  For a file of GAEB DA XML 3.0 or 3.1, which is read only, stages 1 and 2
  are not available; -xsd=<folder> validates it against its original
  schemas.

  With -convert=3.2|3.3 the file is not checked as it is but as it would
  be saved in that version (same phase), for example a file of GAEB DA XML
  3.0 or 3.1, which is read only (LandrixGaebConversion): writing (losses),
  content model check and business rules of the output, with -xsd=<folder>
  also the XSD validation of the output. Exit code 0 if every check that
  ran passed, 1 otherwise.

  Usage: CheckGaeb [-xsd=<folder>] <file> [<second file>]
         CheckGaeb [-xsd=<folder>] -convert=3.2|3.3 <file> }

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
  Classes,
  LandrixXmlBase,
  LandrixGaebTypes,
  LandrixGaebDiagnostics,
  LandrixGaebDetect,
  LandrixGaebXmlModel,
  LandrixGaebXmlReader,
  LandrixGaebXmlCheck,
  LandrixGaebXmlXsd,
  LandrixGaebRules,
  LandrixGaebBoQ,
  LandrixGaebConversion;

var
  { the arguments without -xsd=; the schema folder, '' without }
  Files: array of string;
  XsdFolder: string;
  { the version of -convert=; ConvertGiven tells whether the option was given }
  ConvertTo: string;
  ConvertGiven: Boolean;

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
  { GAEB DA XML 3.0 and 3.1 are read only: no content model check and no
    business rules of their own (-convert= checks them as 3.2 or 3.3), but
    the XSD validation against their original schemas }
  Det := LandrixGaebDetectFile(AFileName, nil, 0);
  if Det.Accepted and (Det.Format = gfXml) and (Det.Target.Version in [gv30, gv31]) then
  begin
    WriteLn(AFileName, ': GAEB DA XML ', TargetText(Det.Target));
    WriteLn('  content model check and business rules: not available for this version (see -convert=)');
    if ASchemas <> nil then
      WriteLn('  XSD validation: ', Passed(LandrixGaebXmlXsdValidateFile(ASchemas, AFileName, ADiagnostics, 0,
        Det)));
    Result := LandrixGaebXmlReadFile(AFileName, ADiagnostics, 0, Det);
    ATarget := Det.Target;
    Exit;
  end;
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

function StateText(AState: TLandrixGaebConversionState): string;
begin
  case AState of
    gcrPassed:
      Result := 'passed';
    gcrFailed:
      Result := 'errors found';
  else
    Result := 'not run';
  end;
end;

{ -convert=: the checks of the file as it would be saved in ConvertTo. }
procedure RunConversion;
var
  ReadDiags, Diags: TLandrixGaebDiagnostics;
  Bill: TLandrixGaebBillOfQuantities;
  Target: TLandrixGaebTarget;
  R: TLandrixGaebConversionResult;
  Output: TMemoryStream;
  Schemas: TLandrixGaebXmlXsdSchemas;
  XsdOk: Boolean;
begin
  ReadDiags := TLandrixGaebDiagnostics.Create;
  Diags := TLandrixGaebDiagnostics.Create;
  Output := TMemoryStream.Create;
  Bill := nil;
  Schemas := nil;
  XsdOk := True;
  R.Writing := gcrNotRun;
  R.Structure := gcrNotRun;
  R.Rules := gcrNotRun;
  try
    try
      Bill := TLandrixGaebBillOfQuantities.LoadFromFile(Files[0], ReadDiags, 0);
      Target := Bill.Target;
      if ConvertTo = '3.2' then
      begin
        Target.Version := gv32;
        Target.Edition := ge2013_10;
      end
      else
      begin
        Target.Version := gv33;
        Target.Edition := ge2021_05;
      end;
      WriteLn(Files[0], ': GAEB DA XML ', TargetText(Bill.Target), ' as ', TargetText(Target));
      R := LandrixGaebCheckConversion(Bill, Target, Diags, Output);
      WriteLn('  writing (losses): ', StateText(R.Writing));
      WriteLn('  content model check: ', StateText(R.Structure));
      WriteLn('  business rules (rule set ', LandrixGaebRuleSetVersion, '): ', StateText(R.Rules));
      if (XsdFolder <> '') and (Output.Size > 0) then
      begin
        Schemas := TLandrixGaebXmlXsdSchemas.Create(XsdFolder);
        XsdOk := LandrixGaebXmlXsdValidateTarget(Schemas, Output.Memory, Integer(Output.Size), Target,
          Diags);
        WriteLn('  XSD validation: ', Passed(XsdOk));
      end;
    finally
      Schemas.Free;
      Bill.Free;
      { findings of reading the file (paths of the file) apart from those of
        the conversion (paths of the output) }
      WriteLn('reading:');
      Write(ReadDiags.ToText);
      WriteLn('conversion:');
      Write(Diags.ToText);
      WriteLn(ReadDiags.Count + Diags.Count, ' finding(s)');
    end;
    if ReadDiags.HasErrors or Diags.HasErrors or (R.Writing = gcrFailed) or
      (R.Structure = gcrFailed) or (R.Rules = gcrFailed) or not XsdOk then
      ExitCode := 1;
  finally
    Output.Free;
    Diags.Free;
    ReadDiags.Free;
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
        if (FirstTarget.Version in [gv30, gv31]) or (SecondTarget.Version in [gv30, gv31]) then
          WriteLn('pair rules: not available for this version')
        else
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
  ConvertTo := '';
  ConvertGiven := False;
  SetLength(Files, 0);
  for I := 1 to ParamCount do
    if Copy(ParamStr(I), 1, 5) = '-xsd=' then
      XsdFolder := Copy(ParamStr(I), 6, MaxInt)
    else if Copy(ParamStr(I), 1, 9) = '-convert=' then
    begin
      ConvertTo := Copy(ParamStr(I), 10, MaxInt);
      ConvertGiven := True;
    end
    else
    begin
      SetLength(Files, Length(Files) + 1);
      Files[High(Files)] := ParamStr(I);
    end;
end;

begin
  ReadArguments;
  if (Length(Files) < 1) or (Length(Files) > 2) or
    (ConvertGiven and ((Length(Files) <> 1) or ((ConvertTo <> '3.2') and (ConvertTo <> '3.3')))) then
  begin
    WriteLn('Usage: CheckGaeb [-xsd=<folder>] <file> [<second file>]');
    WriteLn('       CheckGaeb [-xsd=<folder>] -convert=3.2|3.3 <file>');
    ExitCode := 2;
    Exit;
  end;
  try
    if ConvertGiven then
      RunConversion
    else
      Run;
  except
    on E: Exception do
    begin
      WriteLn(E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
