{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Validation against the GAEB XSD schemas with the XSD validator of
  LandrixXml (stage 5), and agreement of the content model check (stage 2)
  with it. The schemas are not part of the repository: the tests read them
  from Specification/ and skip when it is missing. Local files under
  tests/data/local are only counted, never printed. }

unit LandrixGaebTestXsd;

{$I LandrixGaeb.inc}

interface

procedure Register;

implementation

uses
  SysUtils,
  Classes,
  LandrixXmlBase,
  LandrixXmlReader,
  LandrixXmlXsdSchema,
  LandrixXmlXsdSchemaLoader,
  LandrixXmlXsdValidator,
  LandrixGaebTypes,
  LandrixGaebDiagnostics,
  LandrixGaebDetect,
  LandrixGaebXmlModel,
  LandrixGaebXmlReader,
  LandrixGaebXmlWriter,
  LandrixGaebXmlCheck,
  LandrixGaebTestNoValues,
  LandrixGaebTestFramework;

const
  { the published targets of the model: three editions, eight phases (80 to 87) }
  TargetCount = 24;

var
  Schemas: array[0..TargetCount - 1] of TLandrixXmlXsdSchemaSet;

function TargetOf(AIndex: Integer): TLandrixGaebTarget;
const
  Phases: array[0..7] of TLandrixGaebPhase = (gp80, gp81, gp82, gp83, gp84, gp85, gp86, gp87);
begin
  case AIndex div 8 of
    0: Result := LandrixGaebTarget(gv32, ge2013_10, Phases[AIndex mod 8]);
    1: Result := LandrixGaebTarget(gv33, ge2019_11, Phases[AIndex mod 8]);
  else
    Result := LandrixGaebTarget(gv33, ge2021_05, Phases[AIndex mod 8]);
  end;
end;

function TargetIndex(const ATarget: TLandrixGaebTarget): Integer;
var
  I: Integer;
  T: TLandrixGaebTarget;
begin
  Result := -1;
  for I := 0 to TargetCount - 1 do
  begin
    T := TargetOf(I);
    if (T.Version = ATarget.Version) and (T.Edition = ATarget.Edition) and (T.Phase = ATarget.Phase) then
      Result := I;
  end;
end;

function TargetName(AIndex: Integer): string;
var
  T: TLandrixGaebTarget;
begin
  T := TargetOf(AIndex);
  Result := LandrixXmlUtf8ToString(LandrixGaebVersionToText(T.Version)) + '/' +
    LandrixXmlUtf8ToString(LandrixGaebEditionToText(T.Edition)) + '/' +
    LandrixXmlUtf8ToString(LandrixGaebPhaseToDP(T.Phase));
end;

function SchemaDir: string;
begin
  Result := RepositoryRoot + 'Specification' + PathDelim;
end;

function HaveSchemas: Boolean;
begin
  Result := DirectoryExists(SchemaDir + 'XML-3.3' + PathDelim + 'Schema');
  if not Result then
    Skip('Specification/ with the GAEB schemas not present');
end;

{ The schema of a target, loaded once. }
function SchemaOf(AIndex: Integer): TLandrixXmlXsdSchemaSet;
var
  T: TLandrixGaebTarget;
  V, E, DP: string;
begin
  if Schemas[AIndex] = nil then
  begin
    T := TargetOf(AIndex);
    V := LandrixXmlUtf8ToString(LandrixGaebVersionToText(T.Version));
    E := LandrixXmlUtf8ToString(LandrixGaebEditionToText(T.Edition));
    DP := LandrixXmlUtf8ToString(LandrixGaebPhaseToDP(T.Phase));
    Schemas[AIndex] := LandrixXmlXsdLoadSchema(SchemaDir + 'XML-' + V + PathDelim + 'Schema' + PathDelim +
      'GAEB_DA_XML_' + DP + '_' + V + '_' + E + '.xsd');
  end;
  Result := Schemas[AIndex];
end;

{ True if the document is valid for the schema of target AIndex; AError
  gets the code of the first error. }
function XsdValid(const ASource: TLandrixXmlUtf8; AIndex: Integer; out AError: string): Boolean;
var
  Validator: TLandrixXmlXsdValidator;
  Reader: TLandrixXmlReader;
begin
  AError := '';
  Validator := TLandrixXmlXsdValidator.Create(SchemaOf(AIndex));
  Reader := TLandrixXmlReader.Create;
  try
    Reader.LoadFromUtf8(ASource);
    Result := Validator.ValidateReader(Reader);
    if not Result then
      AError := Validator.Errors[0].Code + ' ' + LandrixXmlUtf8ToString(Validator.Errors[0].Path) + ' ' +
        Validator.Errors[0].Message;
  finally
    Reader.Free;
    Validator.Free;
  end;
end;

{ Verdict of the content model check. }
function CheckValid(const ASource: TLandrixXmlUtf8; out AError: string): Boolean;
var
  Diags: TLandrixGaebDiagnostics;
  Det: TLandrixGaebDetection;
begin
  AError := '';
  Diags := TLandrixGaebDiagnostics.Create;
  try
    Result := LandrixGaebXmlCheckBuffer(Pointer(ASource), Integer(Length(ASource)), Diags, Det);
    if not Result and (Diags.Count > 0) then
      AError := Diags[0].RuleId;
  finally
    Diags.Free;
  end;
end;

function TargetOfSource(const ASource: TLandrixXmlUtf8): Integer;
var
  Det: TLandrixGaebDetection;
begin
  Det := LandrixGaebDetectBuffer(Pointer(ASource), Integer(Length(ASource)), False, nil);
  Result := -1;
  if Det.Accepted and (Det.Format = gfXml) then
    Result := TargetIndex(Det.Target);
end;

function ReplaceFirst(const S, APart, AWith: TLandrixXmlUtf8): TLandrixXmlUtf8;
var
  P: Integer;
begin
  Result := S;
  P := Pos(APart, S);
  if P > 0 then
    Result := Copy(S, 1, P - 1) + AWith + Copy(S, P + Integer(Length(APart)), MaxInt);
end;

function DataDir(const ASub: string): string;
begin
  Result := RepositoryRoot + 'tests' + PathDelim + 'data' + PathDelim + ASub + PathDelim;
end;

{ Files below ADir (recursive) in AList. }
procedure ListFiles(const ADir: string; AList: TStrings);
var
  SR: TSearchRec;
begin
  if FindFirst(ADir + '*', faAnyFile, SR) = 0 then
  try
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then
        Continue;
      if (SR.Attr and faDirectory) <> 0 then
        ListFiles(ADir + SR.Name + PathDelim, AList)
      else
        AList.Add(ADir + SR.Name);
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

{ ---- the committed test documents ---- }

procedure CheckDocuments(const ASub: string);
var
  Files: TStringList;
  I, T: Integer;
  Source: TLandrixXmlUtf8;
  Name, XsdError, CheckError: string;
  Valid, Expected: Boolean;
begin
  Files := TStringList.Create;
  try
    ListFiles(DataDir(ASub), Files);
    Files.Sort;
    for I := 0 to Files.Count - 1 do
    begin
      Name := ExtractFileName(Files[I]);
      if (Name = 'expected.txt') or (Pos('latin1', Name) > 0) then
        Continue;
      Source := ReadFileBytes(Files[I]);
      T := TargetOfSource(Source);
      Check(T >= 0, Name + ': a target of the model');
      if T < 0 then
        Continue;
      Expected := Pos('-invalid', Name) = 0;
      Valid := XsdValid(Source, T, XsdError);
      Check(Valid = Expected, ASub + '/' + Name + ': XSD ' + XsdError);
      Check(CheckValid(Source, CheckError) = Valid, ASub + '/' + Name + ': the check agrees with the XSD (' +
        CheckError + ', ' + XsdError + ')');
    end;
    Check(Files.Count > 0, ASub + ': documents found');
  finally
    Files.Free;
  end;
end;

procedure TestRuleCases;
begin
  if HaveSchemas then
    CheckDocuments('rules');
end;

procedure TestLegacyCases;
begin
  if HaveSchemas then
    CheckDocuments('legacy');
end;

{ The documents of the bid process and the request X81 written as X83. }
procedure TestProcessCases;
var
  Source, Output: TLandrixXmlUtf8;
  G: TLandrixGaebXmlGAEB;
  Det: TLandrixGaebDetection;
  T: Integer;
  XsdError: string;
begin
  if not HaveSchemas then
    Exit;
  CheckDocuments('process');
  Source := ReadFileBytes(DataDir('process') + 'request.x81');
  G := LandrixGaebXmlReadBuffer(Pointer(Source), Integer(Length(Source)), nil, Det);
  try
    T := TargetIndex(LandrixGaebTarget(Det.Target.Version, Det.Target.Edition, gp83));
    Output := LandrixGaebXmlWriteUtf8(G, TargetOf(T), LandrixGaebXmlDefaultWriteOptions, nil);
  finally
    G.Free;
  end;
  Check(XsdValid(Output, T, XsdError), 'request.x81 written as X83: XSD ' + XsdError);
end;

{ The coverage documents and their writer output (3.3/2019-11 written as
  2021-05, the same namespace). }
procedure TestCoverageCases;
var
  Files: TStringList;
  I, T, W: Integer;
  Source, Output: TLandrixXmlUtf8;
  G: TLandrixGaebXmlGAEB;
  Det: TLandrixGaebDetection;
  Name, XsdError: string;
begin
  if not HaveSchemas then
    Exit;
  CheckDocuments('coverage');
  Files := TStringList.Create;
  try
    ListFiles(DataDir('coverage'), Files);
    for I := 0 to Files.Count - 1 do
    begin
      Name := ExtractFileName(Files[I]);
      Source := ReadFileBytes(Files[I]);
      G := LandrixGaebXmlReadBuffer(Pointer(Source), Integer(Length(Source)), nil, Det);
      try
        T := TargetIndex(Det.Target);
        W := T;
        if not LandrixGaebTargetIsSupported(Det.Target, True) then
          W := TargetIndex(LandrixGaebTarget(gv33, ge2021_05, Det.Target.Phase));
        Output := LandrixGaebXmlWriteUtf8(G, TargetOf(W), LandrixGaebXmlDefaultWriteOptions, nil);
        Check(XsdValid(Output, W, XsdError), Name + ' written for ' + TargetName(W) + ': XSD ' + XsdError);
      finally
        G.Free;
      end;
    end;
  finally
    Files.Free;
  end;
end;

{ ---- the writer: output for every target is valid ---- }

procedure TestWriterTargets;
var
  Names: array[0..1] of string;
  I, N, T: Integer;
  Source, Output: TLandrixXmlUtf8;
  G: TLandrixGaebXmlGAEB;
  Det: TLandrixGaebDetection;
  Options: TLandrixGaebXmlWriteOptions;
  XsdError: string;
begin
  if not HaveSchemas then
    Exit;
  Names[0] := '31-elements.x83';
  Names[1] := '31-elements.x84';
  Options := LandrixGaebXmlDefaultWriteOptions;
  Options.Mode := gwmBestEffort;
  for N := 0 to 1 do
  begin
    Source := ReadFileBytes(DataDir('legacy') + Names[N]);
    G := LandrixGaebXmlReadBuffer(Pointer(Source), Integer(Length(Source)), nil, Det);
    try
      for I := 0 to TargetCount - 1 do
      begin
        T := I;
        if (TargetOf(T).Phase <> Det.Target.Phase) or not LandrixGaebTargetIsSupported(TargetOf(T), True) then
          Continue;
        Output := LandrixGaebXmlWriteUtf8(G, TargetOf(T), Options, nil);
        Check(XsdValid(Output, T, XsdError), Names[N] + ' written for ' + TargetName(T) + ': XSD ' + XsdError);
      end;
    finally
      G.Free;
    end;
  end;
end;

{ ---- stage 2 against the XSD on targeted mutations, every target ---- }

type
  { Phases: 0 both, 83 or 84 only }
  TMutation = record
    Phase: Integer;
    Find: TLandrixXmlUtf8;
    Replace: TLandrixXmlUtf8;
  end;

const
  MutationCount = 14;
  { every mutation breaks the schema: missing, repeated, enumeration,
    length, digits, attributes, ID and IDREF, unknown element, text in
    element content }
  Mutations: array[0..MutationCount - 1] of TMutation = (
    (Phase: 83; Find: '<LblBoQ>Test</LblBoQ>'; Replace: ''),
    (Phase: 0; Find: '<Name>LV</Name>'; Replace: '<Name>LV</Name><Name>LV</Name>'),
    (Phase: 83; Find: '<OutlCompl>AllTxt</OutlCompl>'; Replace: '<OutlCompl>Everything</OutlCompl>'),
    (Phase: 0; Find: '<Name>LV</Name>'; Replace: '<Name>LV-Name-longer-than-twenty</Name>'),
    (Phase: 83; Find: '<Qty>10.000</Qty>'; Replace: '<Qty>10.0001</Qty>'),
    (Phase: 84; Find: '<IT>50.00</IT>'; Replace: '<IT>50.001</IT>'),
    (Phase: 0; Find: '<BoQ ID="B1">'; Replace: '<BoQ ID="B1" Unknown="1">'),
    (Phase: 0; Find: ' RNoPart="0010"'; Replace: ''),
    (Phase: 0; Find: 'ID="I2"'; Replace: 'ID="I1"'),
    (Phase: 83; Find: 'IDRef="I6"'; Replace: 'IDRef="I99"'),
    (Phase: 0; Find: 'ID="I1"'; Replace: 'ID="1I"'),
    (Phase: 0; Find: '<BoQInfo>'; Replace: '<BoQInfo><Unknown/>'),
    (Phase: 0; Find: '<BoQInfo>'; Replace: '<BoQInfo>text'),
    (Phase: 0; Find: '<Type>BoQLevel</Type>'; Replace: '<Type>Level</Type>')
  );

procedure TestAgreement;
var
  Names: array[0..1] of string;
  I, M, N, Compared: Integer;
  Source, Base, Mutant: TLandrixXmlUtf8;
  G: TLandrixGaebXmlGAEB;
  Det: TLandrixGaebDetection;
  Options: TLandrixGaebXmlWriteOptions;
  XsdError, CheckError: string;
  XsdOk, CheckOk: Boolean;
begin
  if not HaveSchemas then
    Exit;
  Names[0] := '31-elements.x83';
  Names[1] := '31-elements.x84';
  Options := LandrixGaebXmlDefaultWriteOptions;
  Options.Mode := gwmBestEffort;
  Compared := 0;
  for N := 0 to 1 do
  begin
    Source := ReadFileBytes(DataDir('legacy') + Names[N]);
    G := LandrixGaebXmlReadBuffer(Pointer(Source), Integer(Length(Source)), nil, Det);
    try
      for I := 0 to TargetCount - 1 do
      begin
        if TargetOf(I).Phase <> Det.Target.Phase then
          Continue;
        if LandrixGaebTargetIsSupported(TargetOf(I), True) then
          Base := LandrixGaebXmlWriteUtf8(G, TargetOf(I), Options, nil)
        else
          { 3.3/2019-11 is read, not written: the 2021-05 output with the
            VersDate of 2019-11 (same namespace) }
          Base := ReplaceFirst(LandrixGaebXmlWriteUtf8(G, LandrixGaebTarget(gv33, ge2021_05, Det.Target.Phase),
            Options, nil), '<VersDate>2021-05</VersDate>', '<VersDate>2019-11</VersDate>');
        XsdOk := XsdValid(Base, I, XsdError);
        Check(XsdOk, Names[N] + ' for ' + TargetName(I) + ' is XSD-valid: ' + XsdError);
        Check(CheckValid(Base, CheckError) = XsdOk, Names[N] + ' for ' + TargetName(I) + ': the check agrees (' +
          CheckError + ')');
        for M := 0 to MutationCount - 1 do
        begin
          if (Mutations[M].Phase = 83) and (Det.Target.Phase <> gp83) or
            (Mutations[M].Phase = 84) and (Det.Target.Phase <> gp84) then
            Continue;
          Check(Pos(Mutations[M].Find, Base) > 0, TargetName(I) + ' mutation ' + IntToStr(M) + ' applies');
          Mutant := ReplaceFirst(Base, Mutations[M].Find, Mutations[M].Replace);
          XsdOk := XsdValid(Mutant, I, XsdError);
          CheckOk := CheckValid(Mutant, CheckError);
          Check(not XsdOk, TargetName(I) + ' mutation ' + IntToStr(M) + ' breaks the schema');
          Check(CheckOk = XsdOk, TargetName(I) + ' mutation ' + IntToStr(M) + ': the check agrees with the XSD (' +
            CheckError + ', ' + XsdError + ')');
          Inc(Compared);
        end;
      end;
    finally
      G.Free;
    end;
  end;
  { 3 editions x (9 mutations in both phases + 4 in X83 + 1 in X84) }
  CheckEquals(3 * (2 * 9 + 4 + 1), Compared, 'mutations compared');
end;

{ ---- local files: counts only ---- }

{ Verdict of both on a local file: an exception counts as rejection. }
procedure LocalVerdicts(const ASource: TLandrixXmlUtf8; AIndex: Integer; out AXsdOk, ACheckOk: Boolean);
var
  Error: string;
begin
  try
    AXsdOk := XsdValid(ASource, AIndex, Error);
  except
    on ELandrixXmlError do
      AXsdOk := False;
  end;
  try
    ACheckOk := CheckValid(ASource, Error);
  except
    on ELandrixXmlError do
      ACheckOk := False;
  end;
end;

procedure TestLocal;
var
  Files: TStringList;
  I, T, Checked, Agree, Valid, Written, WrittenValid, Failed, Converted, ConvertedValid: Integer;
  Source, Output: TLandrixXmlUtf8;
  XsdError, FirstFailure: string;
  XsdOk, CheckOk: Boolean;
  G: TLandrixGaebXmlGAEB;
  Det: TLandrixGaebDetection;
begin
  if not HaveSchemas then
    Exit;
  if not DirectoryExists(DataDir('local')) then
  begin
    Skip('tests/data/local not present');
    Exit;
  end;
  { load every schema first: a schema error must not count as a verdict }
  for I := 0 to TargetCount - 1 do
    SchemaOf(I);
  Checked := 0;
  Agree := 0;
  Valid := 0;
  Written := 0;
  WrittenValid := 0;
  Failed := 0;
  Converted := 0;
  ConvertedValid := 0;
  FirstFailure := '';
  Files := TStringList.Create;
  try
    ListFiles(DataDir('local'), Files);
    for I := 0 to Files.Count - 1 do
    { messages of exceptions may quote the file: only the class is kept }
    try
      Source := ReadFileBytes(Files[I]);
      T := TargetOfSource(Source);
      if T < 0 then
        Continue;
      Inc(Checked);
      LocalVerdicts(Source, T, XsdOk, CheckOk);
      if XsdOk then
        Inc(Valid);
      if CheckOk = XsdOk then
        Inc(Agree);
      { a valid 3.2 file converted to 3.3/2021-05 stays valid }
      if XsdOk and (TargetOf(T).Version = gv32) then
      begin
        G := LandrixGaebXmlReadBuffer(Pointer(Source), Integer(Length(Source)), nil, Det);
        try
          Output := LandrixGaebXmlWriteUtf8(G, TargetOf(T + 16), LandrixGaebXmlDefaultWriteOptions, nil);
        finally
          G.Free;
        end;
        Inc(Converted);
        if XsdValid(Output, T + 16, XsdError) then
          Inc(ConvertedValid);
      end;
      if XsdOk and LandrixGaebTargetIsSupported(TargetOf(T), True) then
      begin
        G := LandrixGaebXmlReadBuffer(Pointer(Source), Integer(Length(Source)), nil, Det);
        try
          Output := LandrixGaebXmlWriteUtf8(G, TargetOf(T), LandrixGaebXmlDefaultWriteOptions, nil);
        finally
          G.Free;
        end;
        Inc(Written);
        if XsdValid(Output, T, XsdError) then
          Inc(WrittenValid);
      end;
    except
      on E: Exception do
      begin
        Inc(Failed);
        if FirstFailure = '' then
          FirstFailure := E.ClassName;
      end;
    end;
  finally
    Files.Free;
  end;
  WriteLn('  Local.Xsd: ', Checked, ' file(s), ', Valid, ' XSD-valid, check agrees on ', Agree,
    '; ', Written, ' written, ', WrittenValid, ' of them XSD-valid; ', Converted, ' converted 3.2 -> 3.3, ',
    ConvertedValid, ' of them XSD-valid; ', Failed, ' failed');
  Check(Checked > 0, 'local files found');
  CheckEquals(0, Failed, 'no exception (first: ' + FirstFailure + ')');
  CheckEquals(Checked, Agree, 'the check agrees with the XSD on every local file');
  CheckEquals(Written, WrittenValid, 'the writer keeps every valid local file valid');
  CheckEquals(Converted, ConvertedValid, 'every valid 3.2 file is valid after the conversion to 3.3');
end;

procedure Register;
begin
  RegisterTest('Xsd.RuleCases', TestRuleCases);
  RegisterTest('Xsd.LegacyCases', TestLegacyCases);
  RegisterTest('Xsd.ProcessCases', TestProcessCases);
  RegisterTest('Xsd.CoverageCases', TestCoverageCases);
  RegisterTest('Xsd.WriterTargets', TestWriterTargets);
  RegisterTest('Xsd.Agreement', TestAgreement);
  RegisterTest('Local.Xsd', TestLocal);
end;

procedure FreeSchemas;
var
  I: Integer;
begin
  for I := 0 to TargetCount - 1 do
  begin
    Schemas[I].Free;
    Schemas[I] := nil;
  end;
end;

initialization

finalization
  FreeSchemas;
end.
