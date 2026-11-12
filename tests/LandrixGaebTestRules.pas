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
  LandrixXmlBase,
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
  Raised: Boolean;
begin
  for I := 0 to LandrixGaebRuleCount - 1 do
  begin
    Check(Pos('GAEB-BR-', LandrixGaebRuleAt(I).ID) = 1, 'identifier ' + LandrixGaebRuleAt(I).ID);
    Check(LandrixGaebRuleAt(I).Title <> '', 'title of ' + LandrixGaebRuleAt(I).ID);
    Check(LandrixGaebRuleAt(I).Source <> '', 'source of ' + LandrixGaebRuleAt(I).ID);
    Check(LandrixGaebRuleAt(I).Phases <> [], 'phases of ' + LandrixGaebRuleAt(I).ID);
    Check(LandrixGaebRuleAt(I).Pair = (Pos('-PAIR-', LandrixGaebRuleAt(I).ID) > 0),
      'pair flag of ' + LandrixGaebRuleAt(I).ID);
    CheckEquals(I, LandrixGaebRuleIndex(LandrixGaebRuleAt(I).ID), 'index of ' + LandrixGaebRuleAt(I).ID);
    for J := I + 1 to LandrixGaebRuleCount - 1 do
      Check(LandrixGaebRuleAt(I).ID <> LandrixGaebRuleAt(J).ID, 'unique ' + LandrixGaebRuleAt(I).ID);
  end;
  CheckEquals(-1, LandrixGaebRuleIndex('GAEB-BR-NONE'), 'unknown rule');
  Raised := False;
  try
    LandrixGaebRuleAt(LandrixGaebRuleCount);
  except
    on ELandrixGaebError do
      Raised := True;
  end;
  Check(Raised, 'rule index beyond the catalogue');
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

{ The file of a pair case that starts with APrefix ('first.', 'second.'). }
function PairFile(const ADir, APrefix: string): string;
var
  SR: TSearchRec;
begin
  Result := '';
  if FindFirst(ADir + APrefix + '*', faAnyFile, SR) = 0 then
  try
    Result := ADir + SR.Name;
  finally
    FindClose(SR);
  end;
end;

procedure RunPair(const ARuleId, ADir, AName: string; AExpected: Integer; const APath: string);
var
  A, B: TLandrixGaebXmlGAEB;
  TA, TB: TLandrixGaebTarget;
  Diags: TLandrixGaebDiagnostics;
  N: Integer;
  First, FirstFile, SecondFile: string;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  A := nil;
  B := nil;
  try
    FirstFile := PairFile(ADir + AName + PathDelim, 'first.');
    SecondFile := PairFile(ADir + AName + PathDelim, 'second.');
    A := ReadCase(FirstFile, TA);
    B := ReadCase(SecondFile, TB);
    LandrixGaebCheckPair(A, TA, B, TB, Diags);
    CheckNoFileValues(ReadFileBytes(FirstFile), Diags, ARuleId + '/' + AName);
    CheckNoFileValues(ReadFileBytes(SecondFile), Diags, ARuleId + '/' + AName);
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

{ The phase a case belongs to: for a pair the phase of the rule (that of
  the second document), else the extension of the file.
  DE: Phase eines Falls: bei einem Paar die Phase der Regel (die des
  zweiten Dokuments), sonst die Dateiendung. }
function CasePhase(const AName: string; APhases: TLandrixGaebPhases; out APhase: TLandrixGaebPhase): Boolean;
var
  P: TLandrixGaebPhase;
begin
  Result := False;
  APhase := gpUnknown;
  for P := Low(TLandrixGaebPhase) to High(TLandrixGaebPhase) do
    if (P in APhases) and ((Pos('pair-', AName) = 1) or
      (Copy(AName, Length(AName) - 1, 2) = LandrixXmlUtf8ToString(LandrixGaebPhaseToDP(P)))) then
    begin
      APhase := P;
      Result := True;
    end;
end;

procedure TestCases;
var
  I, J, Count: Integer;
  Dir, Name, Rest, Path, Rule: string;
  Expected: TStringList;
  SR: TSearchRec;
  P: TLandrixGaebPhase;
  Valid, Invalid: array[TLandrixGaebPhase] of Integer;
begin
  Expected := TStringList.Create;
  try
    for I := 0 to LandrixGaebRuleCount - 1 do
    begin
      Rule := LandrixGaebRuleAt(I).ID;
      Dir := RulesDir + Rule + PathDelim;
      for P := Low(TLandrixGaebPhase) to High(TLandrixGaebPhase) do
      begin
        Valid[P] := 0;
        Invalid[P] := 0;
      end;
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
          Check(CasePhase(Name, LandrixGaebRuleAt(I).Phases, P), Rule + '/' + Name +
            ' belongs to a phase of the rule');
          if (Pos('invalid-', Name) > 0) then
          begin
            Check(Count > 0, Rule + '/' + Name + ' listed in expected.txt');
            Inc(Invalid[P]);
          end
          else
            Inc(Valid[P]);
          if Pos('pair-', Name) = 1 then
            RunPair(LandrixGaebRuleAt(I).ID, Dir, Name, Count, Path)
          else
            RunCase(LandrixGaebRuleAt(I).ID, Dir, Name, Count, Path);
        until FindNext(SR) <> 0;
      finally
        FindClose(SR);
      end;
      { every phase of the rule has a valid and an invalid case }
      for P := Low(TLandrixGaebPhase) to High(TLandrixGaebPhase) do
        if P in LandrixGaebRuleAt(I).Phases then
        begin
          Check(Valid[P] > 0, Rule + ' has a valid case for X' + LandrixXmlUtf8ToString(LandrixGaebPhaseToDP(P)));
          Check((Invalid[P] > 0) or IsSchemaGuarded(Rule),
            Rule + ' has an invalid case for X' + LandrixXmlUtf8ToString(LandrixGaebPhaseToDP(P)));
        end;
    end;
  finally
    Expected.Free;
  end;
end;

{ The schema keeps QtyTBD apart from Qty and QtySplit; a model can still
  hold them together. QTY-001 in every phase of the rule, QTY-003 only in
  X83. }
procedure TestSchemaGuarded;
const
  Exts: array[0..5] of string = ('x80', 'x81', 'x82', 'x83', 'x86', 'x87');
var
  G: TLandrixGaebXmlGAEB;
  Target: TLandrixGaebTarget;
  Diags: TLandrixGaebDiagnostics;
  Item: TLandrixGaebXmlItem;
  Path: string;
  I: Integer;
begin
  for I := 0 to High(Exts) do
  begin
    Diags := TLandrixGaebDiagnostics.Create;
    G := ReadCase(RulesDir + 'GAEB-BR-QTY-001' + PathDelim + 'valid-1.' + Exts[I], Target);
    try
      Item := (G.Award.BoQ.BoQBody.Children[0] as TLandrixGaebXmlBoQCtgy).BoQBody.Itemlist.Children[0]
        as TLandrixGaebXmlItem;
      Check(Item.QtyTBD = 'Yes', Exts[I] + ' case holds QtyTBD');
      Item.Qty.SetValue(5, 0);
      Item.QtySplit.Add.Qty.SetValue(5, 0);
      LandrixGaebCheckRules(G, Target, Diags);
      CheckEquals(1, CountRule(Diags, 'GAEB-BR-QTY-001', Path), Exts[I] + ': QtySplit with QtyTBD: ' +
        Diags.ToText);
      CheckEquals(Ord(Target.Phase = gp83), CountRule(Diags, 'GAEB-BR-QTY-003', Path),
        Exts[I] + ': Qty with QtyTBD (X83 only)');
    finally
      G.Free;
      Diags.Free;
    end;
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
    Check(LandrixGaebCheckRules(G, LandrixGaebTarget(gv33, ge2021_05, gp89), nil),
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
  if (Det.Format <> gfXml) or not Det.Accepted or not (Det.Target.Phase in [gp80, gp81, gp82, gp83, gp84, gp85, gp86, gp87]) or
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

{ Checks every file of AFirst against every file of ASecond as pair; a pair
  whose items match (no finding of AMatchA/AMatchB) counts, its findings go
  to ARules. }
procedure TryPairs(AFirst, ASecond: TStringList; AFirstPhase, ASecondPhase: TLandrixGaebPhase;
  const AMatchA, AMatchB: string; var APairs: Integer; ARules: TStringList);
var
  I, J: Integer;
  Det: TLandrixGaebDetection;
  A, B: TLandrixGaebXmlGAEB;
  Diags: TLandrixGaebDiagnostics;
  K: TLandrixGaebListIndex;
begin
  for I := 0 to AFirst.Count - 1 do
    for J := 0 to ASecond.Count - 1 do
    begin
      Diags := TLandrixGaebDiagnostics.Create;
      A := LandrixGaebXmlReadFile(AFirst[I], nil, 0, Det);
      B := nil;
      try
        B := LandrixGaebXmlReadFile(ASecond[J], nil, 0, Det);
        LandrixGaebCheckPair(A, LandrixGaebTarget(gv33, ge2021_05, AFirstPhase), B,
          LandrixGaebTarget(gv33, ge2021_05, ASecondPhase), Diags);
        if (Diags.CountOf(AMatchA) = 0) and (Diags.CountOf(AMatchB) = 0) then
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
end;

{ X83/X84 and X84/X86 in the same folder whose items match are checked as
  pair. Such files need not be counterparts (a later version of the request
  has the same OZ), so the findings are only counted and printed, never
  asserted. }
procedure PairDir(const Dir: string; var APairs8384, APairs8486: Integer; ARules: TStringList);
var
  SR: TSearchRec;
  X83, X84, X86: TStringList;
  Det: TLandrixGaebDetection;
begin
  X83 := TStringList.Create;
  X84 := TStringList.Create;
  X86 := TStringList.Create;
  try
    if FindFirst(Dir + '*', faAnyFile, SR) = 0 then
    try
      repeat
        if (SR.Name = '.') or (SR.Name = '..') then
          Continue;
        if (SR.Attr and faDirectory) <> 0 then
        begin
          PairDir(Dir + SR.Name + PathDelim, APairs8384, APairs8486, ARules);
          Continue;
        end;
        Det := LandrixGaebDetectFile(Dir + SR.Name, nil, 0);
        if (Det.Format = gfXml) and Det.Accepted and
          ((Det.Target.Version = gv32) or (Det.Target.Version = gv33)) and
          LandrixGaebTargetIsSupported(Det.Target, False) then
          if Det.Target.Phase = gp83 then
            X83.Add(Dir + SR.Name)
          else if Det.Target.Phase = gp84 then
            X84.Add(Dir + SR.Name)
          else if Det.Target.Phase = gp86 then
            X86.Add(Dir + SR.Name);
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
    TryPairs(X83, X84, gp83, gp84, 'GAEB-BR-PAIR-83-84-001', 'GAEB-BR-PAIR-83-84-002', APairs8384, ARules);
    TryPairs(X84, X86, gp84, gp86, 'GAEB-BR-PAIR-84-86-001', 'GAEB-BR-PAIR-84-86-001', APairs8486, ARules);
  finally
    X86.Free;
    X84.Free;
    X83.Free;
  end;
end;

procedure TestLocalPairs;
var
  Local, Summary: string;
  Pairs8384, Pairs8486, I, N: Integer;
  Rules: TStringList;
begin
  Local := RepositoryRoot + 'tests' + PathDelim + 'data' + PathDelim + 'local' + PathDelim;
  if not DirectoryExists(Local) then
  begin
    Skip('tests/data/local not present');
    Exit;
  end;
  Pairs8384 := 0;
  Pairs8486 := 0;
  Rules := TStringList.Create;
  try
    Rules.Sorted := True;
    Rules.Duplicates := dupAccept;
    PairDir(Local, Pairs8384, Pairs8486, Rules);
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
    WriteLn('  Local.Pairs: ', Pairs8384, ' matching X83/X84 pair(s), ', Pairs8486, ' matching X84/X86 pair(s),',
      Summary);
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
