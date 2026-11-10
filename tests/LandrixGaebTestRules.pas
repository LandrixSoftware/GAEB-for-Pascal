{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Tests of the business and pair rules (LandrixGaebRules): the catalogue,
  the synthetic cases of tests/data/rules (written by
  tools/rules/make-rule-cases.py; every rule positive and negative), model
  cases for rules whose violation the schema already rejects, and the local
  corpus (skipped when missing; prints counts only, never file content). }

unit LandrixGaebTestRules;

{$I LandrixGaeb.inc}

interface

procedure Register;

implementation

uses
  SysUtils,
  Classes,

  LandrixGaebTypes,
  LandrixGaebDiagnostics,
  LandrixGaebDetect,
  LandrixGaebXmlModel,
  LandrixGaebXmlReader,
  LandrixGaebXmlCheck,
  LandrixGaebRules,
  LandrixGaebTestNoValues,
  LandrixGaebTestFramework;

const
  { rules whose negative case the schema rejects: covered by model cases }
  SchemaGuarded: array[0..1] of string = ('GAEB-BR-QTY-001', 'GAEB-BR-QTY-003');

function RulesDir: string;
begin
  Result := RepositoryRoot + 'tests' + PathDelim + 'data' + PathDelim + 'rules' + PathDelim;
end;

function CountRule(ADiags: TLandrixGaebDiagnostics; const ARuleId: string; out AFirstPath: string): Integer;
var
  I: TLandrixGaebListIndex;
begin
  Result := 0;
  AFirstPath := '';
  for I := 0 to ADiags.Count - 1 do
    if ADiags[I].RuleId = ARuleId then
    begin
      if Result = 0 then
        AFirstPath := string(ADiags[I].Path);
      Inc(Result);
    end;
end;

{ Reads a case file; it must pass the content model check. }
function ReadCase(const AFileName: string; out ATarget: TLandrixGaebTarget): TLandrixGaebXmlGAEB;
var
  Diags: TLandrixGaebDiagnostics;
  Det: TLandrixGaebDetection;
  Ok: Boolean;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  try
    Ok := LandrixGaebXmlCheckFile(AFileName, Diags, 0, Det);
    Check(Ok, ExtractFileName(AFileName) + ' is schema-valid: ' + Diags.ToText);
    Result := LandrixGaebXmlReadFile(AFileName, nil, 0, Det);
    ATarget := Det.Target;
  finally
    Diags.Free;
  end;
end;

procedure TestCatalog;
var
  I, J: Integer;
begin
  for I := 0 to LandrixGaebRuleCount - 1 do
  begin
    Check(Pos('GAEB-BR-', LandrixGaebRuleCatalog[I].ID) = 1, 'identifier ' + LandrixGaebRuleCatalog[I].ID);
    Check(LandrixGaebRuleCatalog[I].Title <> '', 'title of ' + LandrixGaebRuleCatalog[I].ID);
    Check(LandrixGaebRuleCatalog[I].Source <> '', 'source of ' + LandrixGaebRuleCatalog[I].ID);
    Check(LandrixGaebRuleCatalog[I].Phases <> [], 'phases of ' + LandrixGaebRuleCatalog[I].ID);
    Check(LandrixGaebRuleCatalog[I].Pair = (Pos('-PAIR-', LandrixGaebRuleCatalog[I].ID) > 0),
      'pair flag of ' + LandrixGaebRuleCatalog[I].ID);
    CheckEquals(I, LandrixGaebRuleIndex(LandrixGaebRuleCatalog[I].ID), 'index of ' + LandrixGaebRuleCatalog[I].ID);
    for J := I + 1 to LandrixGaebRuleCount - 1 do
      Check(LandrixGaebRuleCatalog[I].ID <> LandrixGaebRuleCatalog[J].ID, 'unique ' + LandrixGaebRuleCatalog[I].ID);
  end;
  CheckEquals(-1, LandrixGaebRuleIndex('GAEB-BR-NONE'), 'unknown rule');
end;

function IsSchemaGuarded(const ARuleId: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(SchemaGuarded) do
    if SchemaGuarded[I] = ARuleId then
      Result := True;
end;

{ Checks one single-document case; returns the number of findings. }
procedure RunCase(const ARuleId, ADir, AName: string; AExpected: Integer; const APath: string);
var
  G: TLandrixGaebXmlGAEB;
  Target: TLandrixGaebTarget;
  Diags: TLandrixGaebDiagnostics;
  N: Integer;
  First: string;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  G := nil;
  try
    G := ReadCase(ADir + AName, Target);
    LandrixGaebCheckRules(G, Target, Diags);
    CheckNoFileValues(ReadFileBytes(ADir + AName), Diags, ARuleId + '/' + AName);
    N := CountRule(Diags, ARuleId, First);
    CheckEquals(AExpected, N, ARuleId + '/' + AName + ': ' + Diags.ToText);
    if AExpected > 0 then
      CheckEqualsStr(APath, First, ARuleId + '/' + AName + ' path');
  finally
    G.Free;
    Diags.Free;
  end;
end;

procedure RunPair(const ARuleId, ADir, AName: string; AExpected: Integer; const APath: string);
var
  A, B: TLandrixGaebXmlGAEB;
  TA, TB: TLandrixGaebTarget;
  Diags: TLandrixGaebDiagnostics;
  N: Integer;
  First: string;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  A := nil;
  B := nil;
  try
    A := ReadCase(ADir + AName + PathDelim + 'first.x83', TA);
    B := ReadCase(ADir + AName + PathDelim + 'second.x84', TB);
    LandrixGaebCheckPair(A, TA, B, TB, Diags);
    CheckNoFileValues(ReadFileBytes(ADir + AName + PathDelim + 'first.x83'), Diags, ARuleId + '/' + AName);
    CheckNoFileValues(ReadFileBytes(ADir + AName + PathDelim + 'second.x84'), Diags, ARuleId + '/' + AName);
    N := CountRule(Diags, ARuleId, First);
    CheckEquals(AExpected, N, ARuleId + '/' + AName + ': ' + Diags.ToText);
    if AExpected > 0 then
      CheckEqualsStr(APath, First, ARuleId + '/' + AName + ' path');
  finally
    B.Free;
    A.Free;
    Diags.Free;
  end;
end;

procedure TestCases;
var
  I, J, Count, Valid, Invalid: Integer;
  Dir, Name, Rest, Path: string;
  Expected: TStringList;
  SR: TSearchRec;
begin
  Expected := TStringList.Create;
  try
    for I := 0 to LandrixGaebRuleCount - 1 do
    begin
      Dir := RulesDir + LandrixGaebRuleCatalog[I].ID + PathDelim;
      Valid := 0;
      Invalid := 0;
      Expected.Clear;
      if FileExists(Dir + 'expected.txt') then
        Expected.LoadFromFile(Dir + 'expected.txt');
      if FindFirst(Dir + '*', faAnyFile, SR) = 0 then
      try
        repeat
          Name := SR.Name;
          if (Name = '.') or (Name = '..') or (Name = 'expected.txt') then
            Continue;
          Count := 0;
          Path := '';
          for J := 0 to Expected.Count - 1 do
            if Pos(Name + ' ', Expected[J]) = 1 then
            begin
              Rest := Copy(Expected[J], Length(Name) + 2, MaxInt);
              Count := StrToInt(Copy(Rest, 1, Pos(' ', Rest) - 1));
              Path := Copy(Rest, Pos(' ', Rest) + 1, MaxInt);
            end;
          if (Pos('invalid-', Name) > 0) then
          begin
            Check(Count > 0, LandrixGaebRuleCatalog[I].ID + '/' + Name + ' listed in expected.txt');
            Inc(Invalid);
          end
          else
            Inc(Valid);
          if Pos('pair-', Name) = 1 then
            RunPair(LandrixGaebRuleCatalog[I].ID, Dir, Name, Count, Path)
          else
            RunCase(LandrixGaebRuleCatalog[I].ID, Dir, Name, Count, Path);
        until FindNext(SR) <> 0;
      finally
        FindClose(SR);
      end;
      Check(Valid > 0, LandrixGaebRuleCatalog[I].ID + ' has a valid case');
      Check((Invalid > 0) or IsSchemaGuarded(LandrixGaebRuleCatalog[I].ID),
        LandrixGaebRuleCatalog[I].ID + ' has an invalid case');
    end;
  finally
    Expected.Free;
  end;
end;

{ The schema keeps QtyTBD apart from Qty and QtySplit; a model can still
  hold them together. }
procedure TestSchemaGuarded;
var
  G: TLandrixGaebXmlGAEB;
  Target: TLandrixGaebTarget;
  Diags: TLandrixGaebDiagnostics;
  Item: TLandrixGaebXmlItem;
  Path: string;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  G := ReadCase(RulesDir + 'GAEB-BR-QTY-001' + PathDelim + 'valid-1.x83', Target);
  try
    Item := (G.Award.BoQ.BoQBody.Children[0] as TLandrixGaebXmlBoQCtgy).BoQBody.Itemlist.Children[0]
      as TLandrixGaebXmlItem;
    Check(Item.QtyTBD = 'Yes', 'case holds QtyTBD');
    Item.Qty.SetValue(5, 0);
    Item.QtySplit.Add.Qty.SetValue(5, 0);
    LandrixGaebCheckRules(G, Target, Diags);
    CheckEquals(1, CountRule(Diags, 'GAEB-BR-QTY-001', Path), 'QtySplit with QtyTBD: ' + Diags.ToText);
    CheckEquals(1, CountRule(Diags, 'GAEB-BR-QTY-003', Path), 'Qty with QtyTBD');
  finally
    G.Free;
    Diags.Free;
  end;
end;

procedure TestPairPhases;
var
  G: TLandrixGaebXmlGAEB;
  Raised: Boolean;
begin
  G := TLandrixGaebXmlGAEB.Create;
  try
    Raised := False;
    try
      LandrixGaebCheckPair(G, LandrixGaebTarget(gv33, ge2021_05, gp84), G,
        LandrixGaebTarget(gv33, ge2021_05, gp83), nil);
    except
      on ELandrixGaebError do
        Raised := True;
    end;
    Check(Raised, 'no pair rules for 84 -> 83');
    Check(LandrixGaebCheckRules(G, LandrixGaebTarget(gv33, ge2021_05, gp86), nil),
      'phase without rules');
  finally
    G.Free;
  end;
end;

{ ---- local corpus ---- }

var
  CorpusChecked, CorpusLeaks: Integer;
  CorpusRules: TStringList;
  CorpusFirstLeak: string;

procedure CorpusFile(const FileName: string);
var
  Det: TLandrixGaebDetection;
  G: TLandrixGaebXmlGAEB;
  Diags: TLandrixGaebDiagnostics;
  I: TLandrixGaebListIndex;
  First: string;
begin
  Det := LandrixGaebDetectFile(FileName, nil, 0);
  if (Det.Format <> gfXml) or not Det.Accepted or not (Det.Target.Phase in [gp83, gp84]) or
    not ((Det.Target.Version = gv32) or (Det.Target.Version = gv33)) or
    not LandrixGaebTargetIsSupported(Det.Target, False) then
    Exit;
  Diags := TLandrixGaebDiagnostics.Create;
  G := LandrixGaebXmlReadFile(FileName, nil, 0, Det);
  try
    LandrixGaebCheckRules(G, Det.Target, Diags);
    Inc(CorpusChecked);
    for I := 0 to Diags.Count - 1 do
      CorpusRules.Add(Diags[I].RuleId);
    { case 37 on real files: reader, check and rules; counts only }
    LandrixGaebXmlReadFile(FileName, Diags, 0, Det).Free;
    LandrixGaebXmlCheckFile(FileName, Diags, 0, Det);
    Inc(CorpusLeaks, CountValueLeaks(FileValues(ReadFileBytes(FileName)), Diags, First));
    if (First <> '') and (CorpusFirstLeak = '') then
      CorpusFirstLeak := First;
  finally
    G.Free;
    Diags.Free;
  end;
end;

procedure CorpusDir(const Dir: string);
var
  SR: TSearchRec;
begin
  if FindFirst(Dir + '*', faAnyFile, SR) = 0 then
  try
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then
        Continue;
      if (SR.Attr and faDirectory) <> 0 then
        CorpusDir(Dir + SR.Name + PathDelim)
      else
        CorpusFile(Dir + SR.Name);
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

procedure TestLocalRules;
var
  Local, Summary: string;
  I, N: Integer;
begin
  Local := RepositoryRoot + 'tests' + PathDelim + 'data' + PathDelim + 'local' + PathDelim;
  if not DirectoryExists(Local) then
  begin
    Skip('tests/data/local not present');
    Exit;
  end;
  CorpusChecked := 0;
  CorpusLeaks := 0;
  CorpusFirstLeak := '';
  CorpusRules := TStringList.Create;
  try
    CorpusRules.Sorted := True;
    CorpusRules.Duplicates := dupAccept;
    CorpusDir(Local + 'xml' + PathDelim);
    CorpusDir(Local + 'official' + PathDelim);
    Summary := '';
    I := 0;
    while I < CorpusRules.Count do
    begin
      N := 1;
      while (I + N < CorpusRules.Count) and (CorpusRules[I + N] = CorpusRules[I]) do
        Inc(N);
      Summary := Summary + ' ' + CorpusRules[I] + 'x' + IntToStr(N);
      Inc(I, N);
    end;
    WriteLn('  Local.Rules: ', CorpusChecked, ' file(s) checked,', Summary);
    WriteLn('  Local.Rules: ', CorpusLeaks, ' message(s) with a value of their file');
    Check(CorpusChecked > 0, 'local files checked');
    CheckEquals(0, CorpusLeaks, 'no message contains a value of its file (' + CorpusFirstLeak + ')');
  finally
    CorpusRules.Free;
    CorpusRules := nil;
  end;
end;

{ X83 and X84 in the same folder whose items match (no finding of
  PAIR-83-84-001/002) are checked as pair. Such files need not be
  counterparts (a later version of the request has the same OZ), so the
  findings are only counted and printed, never asserted. }
procedure PairDir(const Dir: string; var APairs: Integer; ARules: TStringList);
var
  SR: TSearchRec;
  X83, X84: TStringList;
  I, J: Integer;
  Det: TLandrixGaebDetection;
  A, B: TLandrixGaebXmlGAEB;
  Diags: TLandrixGaebDiagnostics;
  K: TLandrixGaebListIndex;
  Matched: Boolean;
begin
  X83 := TStringList.Create;
  X84 := TStringList.Create;
  try
    if FindFirst(Dir + '*', faAnyFile, SR) = 0 then
    try
      repeat
        if (SR.Name = '.') or (SR.Name = '..') then
          Continue;
        if (SR.Attr and faDirectory) <> 0 then
        begin
          PairDir(Dir + SR.Name + PathDelim, APairs, ARules);
          Continue;
        end;
        Det := LandrixGaebDetectFile(Dir + SR.Name, nil, 0);
        if (Det.Format = gfXml) and Det.Accepted and
          ((Det.Target.Version = gv32) or (Det.Target.Version = gv33)) and
          LandrixGaebTargetIsSupported(Det.Target, False) then
          if Det.Target.Phase = gp83 then
            X83.Add(Dir + SR.Name)
          else if Det.Target.Phase = gp84 then
            X84.Add(Dir + SR.Name);
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
    for I := 0 to X83.Count - 1 do
      for J := 0 to X84.Count - 1 do
      begin
        Diags := TLandrixGaebDiagnostics.Create;
        A := LandrixGaebXmlReadFile(X83[I], nil, 0, Det);
        B := nil;
        try
          B := LandrixGaebXmlReadFile(X84[J], nil, 0, Det);
          LandrixGaebCheckPair(A, LandrixGaebTarget(gv33, ge2021_05, gp83), B,
            LandrixGaebTarget(gv33, ge2021_05, gp84), Diags);
          Matched := (Diags.CountOf('GAEB-BR-PAIR-83-84-001') = 0) and
            (Diags.CountOf('GAEB-BR-PAIR-83-84-002') = 0);
          if Matched then
          begin
            Inc(APairs);
            for K := 0 to Diags.Count - 1 do
              ARules.Add(Diags[K].RuleId);
          end;
        finally
          B.Free;
          A.Free;
          Diags.Free;
        end;
      end;
  finally
    X84.Free;
    X83.Free;
  end;
end;

procedure TestLocalPairs;
var
  Local, Summary: string;
  Pairs, I, N: Integer;
  Rules: TStringList;
begin
  Local := RepositoryRoot + 'tests' + PathDelim + 'data' + PathDelim + 'local' + PathDelim;
  if not DirectoryExists(Local) then
  begin
    Skip('tests/data/local not present');
    Exit;
  end;
  Pairs := 0;
  Rules := TStringList.Create;
  try
    Rules.Sorted := True;
    Rules.Duplicates := dupAccept;
    PairDir(Local, Pairs, Rules);
    Summary := '';
    I := 0;
    while I < Rules.Count do
    begin
      N := 1;
      while (I + N < Rules.Count) and (Rules[I + N] = Rules[I]) do
        Inc(N);
      Summary := Summary + ' ' + Rules[I] + 'x' + IntToStr(N);
      Inc(I, N);
    end;
    WriteLn('  Local.Pairs: ', Pairs, ' matching X83/X84 pair(s),', Summary);
  finally
    Rules.Free;
  end;
end;

procedure Register;
begin
  RegisterTest('Rules.Catalog', TestCatalog);
  RegisterTest('Rules.Cases', TestCases);
  RegisterTest('Rules.SchemaGuarded', TestSchemaGuarded);
  RegisterTest('Rules.PairPhases', TestPairPhases);
  RegisterTest('Local.Rules', TestLocalRules);
  RegisterTest('Local.Pairs', TestLocalPairs);
end;

end.
