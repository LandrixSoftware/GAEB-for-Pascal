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
  tests/data/local are only counted, never printed.

  Files of GAEB DA XML 3.0 and 3.1 have no content model check; they are
  validated through LandrixGaebXmlXsd only (committed samples, targeted
  invalid ones and the local corpus).

  With the parameter -export=<folder> every document validated here is
  also written to that folder (numbered, never named after its source),
  with a line in index.txt: file, schema below Specification/, the verdict
  of LandrixXml and whether it comes from the local corpus. The release
  check validates them again with an independent schema processor
  (tools/schema/validate-external.ps1) and compares the verdicts. }

unit LandrixGaebTestXsd;

{$I LandrixGaeb.inc}

{$IFDEF LANDRIXGAEB_UNICODE}
  { DeleteFile is an inline routine on Delphi's POSIX targets and needs
    Posix.Unistd to be expanded (hint H2443); call it out of line. }
  {$INLINE OFF}
{$ENDIF}

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
  LandrixGaebBoQ,
  LandrixGaebXmlXsd,
  LandrixGaebTestNoValues,
  LandrixGaebTestFramework;

const
  { the published targets of the model: three editions, eight phases (80 to 87) }
  TargetCount = 24;

var
  Schemas: array[0..TargetCount - 1] of TLandrixXmlXsdSchemaSet;
  { the same schemas through LandrixGaebXmlXsd }
  ApiSchemas: TLandrixGaebXmlXsdSchemas;
  { export (-export=): folder with trailing delimiter, '' when off; number
    of the last document written; documents from the local corpus }
  ExportFolder: string;
  ExportRead: Boolean;
  ExportCount: Integer;
  ExportLocal: Boolean;

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

{ The main schema of a target below Specification/, separated by '/'. }
function SchemaPath(AIndex: Integer): string;
var
  T: TLandrixGaebTarget;
  V, E, DP: string;
begin
  T := TargetOf(AIndex);
  V := LandrixXmlUtf8ToString(LandrixGaebVersionToText(T.Version));
  E := LandrixXmlUtf8ToString(LandrixGaebEditionToText(T.Edition));
  DP := LandrixXmlUtf8ToString(LandrixGaebPhaseToDP(T.Phase));
  Result := 'XML-' + V + '/Schema/GAEB_DA_XML_' + DP + '_' + V + '_' + E + '.xsd';
end;

{ The schema of a target, loaded once. }
function SchemaOf(AIndex: Integer): TLandrixXmlXsdSchemaSet;
begin
  if Schemas[AIndex] = nil then
    Schemas[AIndex] := LandrixXmlXsdLoadSchema(SchemaDir +
      StringReplace(SchemaPath(AIndex), '/', PathDelim, [rfReplaceAll]));
  Result := Schemas[AIndex];
end;

function ApiSchemasOf: TLandrixGaebXmlXsdSchemas;
begin
  if ApiSchemas = nil then
    ApiSchemas := TLandrixGaebXmlXsdSchemas.Create(SchemaDir);
  Result := ApiSchemas;
end;

{ Validates through LandrixGaebXmlXsd and checks that it agrees with
  AValid (the verdict of the validator used directly), that every error
  is GAEB-XSD-001 with a validator code and that no message quotes a value
  of the document. }
procedure CheckApi(const ASource: TLandrixXmlUtf8; AIndex: Integer; AValid: Boolean; const AContext: string);
var
  Diags: TLandrixGaebDiagnostics;
  I: TLandrixGaebListIndex;
  Ok: Boolean;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  try
    Ok := LandrixGaebXmlXsdValidateTarget(ApiSchemasOf, Pointer(ASource), Integer(Length(ASource)),
      TargetOf(AIndex), Diags);
    Check(Ok = AValid, AContext + ': LandrixGaebXmlXsd agrees with the validator');
    Check(Ok = (Diags.CountOf('GAEB-XSD-001') = 0), AContext + ': GAEB-XSD-001 exactly when invalid');
    for I := 0 to Diags.Count - 1 do
      if Diags[I].RuleId = 'GAEB-XSD-001' then
        Check((Diags[I].XsdCode <> '') and (Pos('(' + Diags[I].XsdCode + ')', Diags[I].Message) > 0),
          AContext + ': the code is in XsdCode and in the message');
    CheckEquals(0, Diags.CountOf('GAEB-XSD-003'), AContext + ': the official schemas match');
    CheckNoFileValues(ASource, Diags, AContext);
  finally
    Diags.Free;
  end;
end;

{ The export folder of -export=, '' when the parameter is missing. }
function ExportDir: string;
var
  I: Integer;
  Index: TStringList;
begin
  if not ExportRead then
  begin
    ExportRead := True;
    ExportFolder := '';
    for I := 1 to ParamCount do
      if Copy(ParamStr(I), 1, 8) = '-export=' then
        ExportFolder := IncludeTrailingPathDelimiter(ExpandFileName(Copy(ParamStr(I), 9, MaxInt)));
    if ExportFolder <> '' then
    begin
      ForceDirectories(ExportFolder);
      { a second run (another filter) continues the numbering }
      if FileExists(ExportFolder + 'index.txt') then
      begin
        Index := TStringList.Create;
        try
          Index.LoadFromFile(ExportFolder + 'index.txt');
          ExportCount := Index.Count;
        finally
          Index.Free;
        end;
      end;
    end;
  end;
  Result := ExportFolder;
end;

procedure AppendLine(const AFileName: string; const ALine: TLandrixXmlUtf8);
var
  F: TFileStream;
  Line: TLandrixXmlUtf8;
begin
  if FileExists(AFileName) then
    F := TFileStream.Create(AFileName, fmOpenReadWrite or fmShareDenyWrite)
  else
    F := TFileStream.Create(AFileName, fmCreate);
  try
    F.Seek(0, soFromEnd);
    Line := ALine + #10;
    F.WriteBuffer(Pointer(Line)^, Length(Line));
  finally
    F.Free;
  end;
end;

{ Writes a validated document and its index line when exporting; ASchema
  is the main schema below Specification/. }
procedure ExportDocumentAs(const ASource: TLandrixXmlUtf8; const ASchema: string; AValid: Boolean);
const
  Verdicts: array[Boolean] of string = ('invalid', 'valid');
  Origins: array[Boolean] of string = ('repo', 'local');
var
  Name: string;
  F: TFileStream;
begin
  if ExportDir = '' then
    Exit;
  Inc(ExportCount);
  Name := Format('%.5d.xml', [ExportCount]);
  F := TFileStream.Create(ExportFolder + Name, fmCreate);
  try
    if Length(ASource) > 0 then
      F.WriteBuffer(Pointer(ASource)^, Length(ASource));
  finally
    F.Free;
  end;
  AppendLine(ExportFolder + 'index.txt', LandrixXmlStringToUtf8(Name + #9 + ASchema + #9 +
    Verdicts[AValid] + #9 + Origins[ExportLocal]));
end;

procedure ExportDocument(const ASource: TLandrixXmlUtf8; AIndex: Integer; AValid: Boolean);
begin
  ExportDocumentAs(ASource, SchemaPath(AIndex), AValid);
end;

{ The main schema of a 3.0/3.1 target below Specification/ (the layout of
  the GAEB packages there), '' for any other target. }
function Schema3xPath(const ATarget: TLandrixGaebTarget): string;
begin
  Result := '';
  if ATarget.Version = gv30 then
    Result := 'XML-3.0/Schema/GAEB_DA_XML.xsd'
  else if (ATarget.Version = gv31) and (ATarget.Edition = ge2007_11) then
  begin
    if ATarget.Phase = gp84 then
      Result := 'XML-3.1/2007-11-20/Schema/GAEB_DA_XML_84.xsd'
    else
      Result := 'XML-3.1/2007-11-20/Schema/GAEB_DA_XML.xsd';
  end
  else if (ATarget.Version = gv31) and (ATarget.Edition = ge2009_12) then
  begin
    if ATarget.Phase = gp84 then
      Result := 'XML-3.1/2009-12/Schema/GAEB_DA_XML_84 3.1 2009-12.xsd'
    else
      Result := 'XML-3.1/2009-12/Schema/GAEB_DA_XML 3.1 2009-12.xsd';
  end;
end;

{ Validates a 3.0/3.1 document through LandrixGaebXmlXsd and exports it with
  the verdict; ADetection gets the detected target. A document that is not
  well-formed counts as invalid. }
function Xsd3xValid(const ASource: TLandrixXmlUtf8; ADiagnostics: TLandrixGaebDiagnostics;
  out ADetection: TLandrixGaebDetection): Boolean;
begin
  try
    Result := LandrixGaebXmlXsdValidateBuffer(ApiSchemasOf, Pointer(ASource), Integer(Length(ASource)),
      ADiagnostics, ADetection);
  except
    on ELandrixXmlError do
    begin
      ADetection := LandrixGaebDetectBuffer(Pointer(ASource), Integer(Length(ASource)), False, nil);
      ExportDocumentAs(ASource, Schema3xPath(ADetection.Target), False);
      raise;
    end;
  end;
  ExportDocumentAs(ASource, Schema3xPath(ADetection.Target), Result);
end;

function XsdValidate(const ASource: TLandrixXmlUtf8; AIndex: Integer; out AError: string): Boolean;
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

{ True if the document is valid for the schema of target AIndex; AError
  gets the code of the first error. An exception counts as invalid for the
  export. }
function XsdValid(const ASource: TLandrixXmlUtf8; AIndex: Integer; out AError: string): Boolean;
begin
  try
    Result := XsdValidate(ASource, AIndex, AError);
  except
    ExportDocument(ASource, AIndex, False);
    raise;
  end;
  ExportDocument(ASource, AIndex, Result);
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
      CheckApi(Source, T, Valid, ASub + '/' + Name);
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
        CheckApi(Base, I, XsdOk, Names[N] + ' for ' + TargetName(I));
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
          CheckApi(Mutant, I, XsdOk, TargetName(I) + ' mutation ' + IntToStr(M));
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

{ A local 3.0/3.1 file: validated when its schema set is known (not the
  trade phases, not DA 88). True if it was validated; AValid gets the
  verdict. }
function Local3x(const ASource: TLandrixXmlUtf8; out AValid: Boolean): Boolean;
var
  Det: TLandrixGaebDetection;
  Diags: TLandrixGaebDiagnostics;
begin
  AValid := False;
  Det := LandrixGaebDetectBuffer(Pointer(ASource), Integer(Length(ASource)), False, nil);
  Result := Det.Accepted and (Det.Format = gfXml) and (Det.Target.Version in [gv30, gv31]) and
    ApiSchemasOf.HasTarget(Det.Target);
  if not Result then
    Exit;
  Diags := TLandrixGaebDiagnostics.Create;
  try
    try
      AValid := Xsd3xValid(ASource, Diags, Det);
    except
      on ELandrixXmlError do
        AValid := False;
    end;
    CheckEquals(0, Diags.CountOf('GAEB-XSD-003'), 'local 3.0/3.1: the schema files are the GAEB files');
  finally
    Diags.Free;
  end;
end;

procedure TestLocal;
var
  Files: TStringList;
  I, T, Checked, Agree, Valid, Written, WrittenValid, Failed, Converted, ConvertedValid: Integer;
  Checked3x, Valid3x: Integer;
  Source, Output: TLandrixXmlUtf8;
  XsdError, FirstFailure: string;
  XsdOk, CheckOk: Boolean;
  G: TLandrixGaebXmlGAEB;
  Det: TLandrixGaebDetection;
begin
  if not HaveSchemas then
    Exit;
  if not DirectoryExists(LocalDataDir) then
  begin
    Skip('local corpus not present');
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
  Checked3x := 0;
  Valid3x := 0;
  FirstFailure := '';
  ExportLocal := True;
  Files := TStringList.Create;
  try
    ListFiles(LocalDataDir, Files);
    for I := 0 to Files.Count - 1 do
    { messages of exceptions may quote the file: only the class is kept }
    try
      Source := ReadFileBytes(Files[I]);
      T := TargetOfSource(Source);
      if T < 0 then
      begin
        if Local3x(Source, XsdOk) then
        begin
          Inc(Checked3x);
          if XsdOk then
            Inc(Valid3x);
        end;
        Continue;
      end;
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
    ExportLocal := False;
    Files.Free;
  end;
  WriteLn('  Local.Xsd: ', Checked, ' file(s), ', Valid, ' XSD-valid, check agrees on ', Agree,
    '; ', Written, ' written, ', WrittenValid, ' of them XSD-valid; ', Converted, ' converted 3.2 -> 3.3, ',
    ConvertedValid, ' of them XSD-valid; ', Checked3x, ' file(s) 3.0/3.1, ', Valid3x, ' of them XSD-valid; ',
    Failed, ' failed');
  Check(Checked > 0, 'local files found');
  CheckEquals(0, Failed, 'no exception (first: ' + FirstFailure + ')');
  CheckEquals(Checked, Agree, 'the check agrees with the XSD on every local file');
  CheckEquals(Written, WrittenValid, 'the writer keeps every valid local file valid');
  CheckEquals(Converted, ConvertedValid, 'every valid 3.2 file is valid after the conversion to 3.3');
end;

{ ---- LandrixGaebXmlXsd: files, models, bills ---- }

function RaisesGaebError(ASchemas: TLandrixGaebXmlXsdSchemas; const ATarget: TLandrixGaebTarget;
  const ASource: TLandrixXmlUtf8): Boolean;
begin
  Result := False;
  try
    LandrixGaebXmlXsdValidateTarget(ASchemas, Pointer(ASource), Integer(Length(ASource)), ATarget, nil);
  except
    on ELandrixGaebError do
      Result := True;
  end;
end;

procedure TestApiModel;
var
  Source: TLandrixXmlUtf8;
  G: TLandrixGaebXmlGAEB;
  Det: TLandrixGaebDetection;
  Diags: TLandrixGaebDiagnostics;
  Bill: TLandrixGaebBillOfQuantities;
  Raised: Boolean;
begin
  if not HaveSchemas then
    Exit;
  Diags := TLandrixGaebDiagnostics.Create;
  try
    Check(LandrixGaebXmlXsdValidateFile(ApiSchemasOf, DataDir('process') + 'request.x83', Diags, 0, Det),
      'request.x83 is valid: ' + Diags.ToText);
    Check(Det.Target.Phase = gp83, 'request.x83 detected as X83');
    Source := ReadFileBytes(DataDir('process') + 'request.x83');
    G := LandrixGaebXmlReadBuffer(Pointer(Source), Integer(Length(Source)), nil, Det);
    try
      Diags.Clear;
      Check(LandrixGaebXmlXsdValidateModel(ApiSchemasOf, G, Det.Target, Diags),
        'the model of request.x83 written again is valid: ' + Diags.ToText);
    finally
      G.Free;
    end;
    Bill := TLandrixGaebBillOfQuantities.LoadFromFile(DataDir('process') + 'bid.x84', nil, 0);
    try
      Diags.Clear;
      Check(LandrixGaebXmlXsdValidateBill(ApiSchemasOf, Bill, Diags), 'bid.x84 as the bill would save it: ' +
        Diags.ToText);
    finally
      Bill.Free;
    end;
    Check(RaisesGaebError(ApiSchemasOf, LandrixGaebTarget(gv31, ge2009_12, gp88), ''),
      'a target without XSD validation raises');
    Raised := False;
    try
      Source := '<a/>';
      LandrixGaebXmlXsdValidateBuffer(ApiSchemasOf, Pointer(Source), Integer(Length(Source)), nil, Det);
    except
      on ELandrixGaebError do
        Raised := True;
    end;
    Check(Raised, 'input that is not GAEB raises');
  finally
    Diags.Free;
  end;
end;

{ ---- LandrixGaebXmlXsd: GAEB DA XML 3.0 and 3.1 ---- }

function Version3x(const AName: string): TLandrixXmlUtf8;
begin
  Result := ReadFileBytes(DataDir('version3x') + AName);
end;

{ A 3.1 request of edition 2007-11 (any VersDate but 2009-12). }
function Request2007: TLandrixXmlUtf8;
begin
  Result := ReplaceFirst(Version3x('v31-2009-12.x83'), '<VersDate>2009-12</VersDate>',
    '<VersDate>2007-06</VersDate>');
end;

{ A 3.1 bid of edition 2007-11. }
function Bid2007: TLandrixXmlUtf8;
begin
  Result := ReplaceFirst(Version3x('v31-2009-12.x84'), '<VersDate>2009-12</VersDate>',
    '<VersDate>2007-06</VersDate>');
end;

{ Validates ASource as detected; checks the target, the verdict and that no
  message quotes a value. }
procedure CheckLegacy(const ASource: TLandrixXmlUtf8; AVersion: TLandrixGaebVersion;
  AEdition: TLandrixGaebEdition; APhase: TLandrixGaebPhase; AValid: Boolean; const AContext: string);
var
  Diags: TLandrixGaebDiagnostics;
  Det: TLandrixGaebDetection;
  Ok: Boolean;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  try
    Ok := Xsd3xValid(ASource, Diags, Det);
    Check((Det.Target.Version = AVersion) and (Det.Target.Edition = AEdition) and (Det.Target.Phase = APhase),
      AContext + ': detected target');
    Check(Ok = AValid, AContext + ': verdict: ' + Diags.ToText);
    Check(Ok = (Diags.CountOf('GAEB-XSD-001') = 0), AContext + ': GAEB-XSD-001 exactly when invalid');
    CheckEquals(0, Diags.CountOf('GAEB-XSD-003'), AContext + ': the schema files are the GAEB files');
    CheckNoFileValues(ASource, Diags, AContext);
  finally
    Diags.Free;
  end;
end;

procedure TestApiVersion3x;
var
  Bill: TLandrixGaebBillOfQuantities;
  G: TLandrixGaebXmlGAEB;
  Det: TLandrixGaebDetection;
  Source: TLandrixXmlUtf8;
  Raised: Boolean;
begin
  if not HaveSchemas then
    Exit;
  { Specification/ holds 3.0 and 3.1/2007-11 both as GAEB_DA_XML.xsd }
  Check(ApiSchemasOf.HasTarget(LandrixGaebTarget(gv30, ge2004_07, gp81)), '3.0 X81 found');
  Check(ApiSchemasOf.HasTarget(LandrixGaebTarget(gv30, ge2004_07, gp84)), '3.0 X84 found');
  Check(ApiSchemasOf.HasTarget(LandrixGaebTarget(gv31, ge2007_11, gp83)), '3.1/2007-11 X83 found');
  Check(ApiSchemasOf.HasTarget(LandrixGaebTarget(gv31, ge2007_11, gp84)), '3.1/2007-11 X84 found');
  Check(ApiSchemasOf.HasTarget(LandrixGaebTarget(gv31, ge2009_12, gp87)), '3.1/2009-12 X87 found');
  Check(not ApiSchemasOf.HasTarget(LandrixGaebTarget(gv30, ge2004_07, gp87)), '3.0 X87 is not read');
  Check(not ApiSchemasOf.HasTarget(LandrixGaebTarget(gv31, ge2007_11, gp87)), '3.1/2007-11 X87 is not read');
  CheckLegacy(Version3x('v30.x81'), gv30, ge2004_07, gp81, True, '3.0 X81');
  CheckLegacy(Version3x('v31-2009-12.x83'), gv31, ge2009_12, gp83, True, '3.1/2009-12 X83');
  CheckLegacy(Version3x('v31-2009-12.x84'), gv31, ge2009_12, gp84, True, '3.1/2009-12 X84');
  CheckLegacy(Request2007, gv31, ge2007_11, gp83, True, '3.1/2007-11 X83');
  CheckLegacy(Bid2007, gv31, ge2007_11, gp84, True, '3.1/2007-11 X84');
  CheckLegacy(ReplaceFirst(Version3x('v31-2009-12.x83'), '<Qty>12.500</Qty>', '<Qty>abc</Qty>'),
    gv31, ge2009_12, gp83, False, '3.1/2009-12 X83 with an invalid quantity');
  CheckLegacy(ReplaceFirst(ReplaceFirst(Version3x('v30.x81'), '<NamePrj>', '<NameProject>'),
    '</NamePrj>', '</NameProject>'), gv30, ge2004_07, gp81,
    False, '3.0 X81 with an unknown element');
  CheckLegacy(ReplaceFirst(Version3x('v31-2009-12.x84'), 'ID="I2"', 'ID="I1"'), gv31, ge2009_12, gp84,
    False, '3.1/2009-12 X84 with a repeated ID');
  CheckLegacy(ReplaceFirst(Bid2007, '<Type>BoQLevel</Type>', '<Type>Level</Type>'), gv31, ge2007_11, gp84,
    False, '3.1/2007-11 X84 with a value outside the enumeration');
  CheckLegacy(ReplaceFirst(Request2007, '<BoQInfo>', '<BoQInfo>text'), gv31, ge2007_11, gp83,
    False, '3.1/2007-11 X83 with text in element content');
  { a model or a bill is written: 3.x cannot be written }
  Source := Version3x('v31-2009-12.x83');
  G := LandrixGaebXmlReadBuffer(Pointer(Source), Integer(Length(Source)), nil, Det);
  try
    Raised := False;
    try
      LandrixGaebXmlXsdValidateModel(ApiSchemasOf, G, Det.Target, nil);
    except
      on ELandrixGaebError do
        Raised := True;
    end;
    Check(Raised, 'ValidateModel rejects a 3.1 target');
  finally
    G.Free;
  end;
  Bill := TLandrixGaebBillOfQuantities.LoadFromFile(DataDir('version3x') + 'v31-2009-12.x83', nil, 0);
  try
    Check(LandrixGaebXmlXsdValidateBill(ApiSchemasOf, Bill, nil), 'a 3.1 bill validates as its 3.3 output');
  finally
    Bill.Free;
  end;
end;

{ ---- LandrixGaebXmlXsd: the schema folder ---- }

procedure WriteBytes(const AFileName: string; const AData: TLandrixXmlUtf8);
var
  F: TFileStream;
begin
  ForceDirectories(ExtractFilePath(AFileName));
  F := TFileStream.Create(AFileName, fmCreate);
  try
    if Length(AData) > 0 then
      F.WriteBuffer(Pointer(AData)^, Length(AData));
  finally
    F.Free;
  end;
end;

procedure DeleteTree(const ADir: string);
var
  SR: TSearchRec;
begin
  if not DirectoryExists(ADir) then
    Exit;
  if FindFirst(ADir + '*', faAnyFile, SR) = 0 then
  try
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then
        Continue;
      if (SR.Attr and faDirectory) <> 0 then
        DeleteTree(ADir + SR.Name + PathDelim)
      else
        DeleteFile(ADir + SR.Name);
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
  RemoveDir(ADir);
end;

procedure TestApiFolder;
const
  MainName = 'GAEB_DA_XML_83_3.3_2021-05.xsd';
  LibName = 'GAEB_DA_XML_Lib_3.3_2021-05.xsd';
  Namespace = 'http://www.gaeb.de/GAEB_DA_XML/DA83/3.3';
var
  Dir, Src: string;
  T: TLandrixGaebTarget;
  Doc, MainXsd, LibXsd: TLandrixXmlUtf8;
  S: TLandrixGaebXmlXsdSchemas;
  Diags: TLandrixGaebDiagnostics;
begin
  if not HaveSchemas then
    Exit;
  Dir := RepositoryRoot + 'build' + PathDelim + 'xsdtest' + PathDelim;
  Src := SchemaDir + 'XML-3.3' + PathDelim + 'Schema' + PathDelim;
  T := LandrixGaebTarget(gv33, ge2021_05, gp83);
  Doc := ReadFileBytes(DataDir('coverage') + '3.3-2021-05-83-minimal.x83');
  MainXsd := ReadFileBytes(Src + MainName);
  LibXsd := ReadFileBytes(Src + LibName);
  Diags := TLandrixGaebDiagnostics.Create;
  try
    { an empty folder }
    DeleteTree(Dir);
    ForceDirectories(Dir);
    S := TLandrixGaebXmlXsdSchemas.Create(Dir);
    try
      Check(not S.HasTarget(T), 'empty folder: no target');
      Check(not S.Verify(Diags), 'empty folder: Verify fails');
      CheckEquals(1, Diags.CountOf('GAEB-XSD-004'), 'empty folder: GAEB-XSD-004');
      Check(RaisesGaebError(S, T, Doc), 'empty folder: validation raises');
    finally
      S.Free;
    end;
    { one target, unpacked one level deeper }
    WriteBytes(Dir + 'pkg' + PathDelim + MainName, MainXsd);
    WriteBytes(Dir + 'pkg' + PathDelim + LibName, LibXsd);
    S := TLandrixGaebXmlXsdSchemas.Create(Dir);
    try
      Check(S.HasTarget(T), 'one target: found');
      Check(not S.HasTarget(LandrixGaebTarget(gv33, ge2021_05, gp84)), 'one target: X84 not there');
      Diags.Clear;
      Check(S.Verify(Diags), 'one target: Verify passes: ' + Diags.ToText);
      CheckEquals(0, Integer(Diags.Count), 'one target: no diagnostic');
      Check(LandrixGaebXmlXsdValidateTarget(S, Pointer(Doc), Integer(Length(Doc)), T, Diags),
        'one target: the document is valid');
      CheckEquals(0, Integer(Diags.Count), 'one target: no diagnostic after validation');
    finally
      S.Free;
    end;
    { a changed Lib file: a warning on every validation, Verify fails }
    WriteBytes(Dir + 'pkg' + PathDelim + LibName, LibXsd + '<!-- changed -->'#10);
    S := TLandrixGaebXmlXsdSchemas.Create(Dir);
    try
      Diags.Clear;
      Check(LandrixGaebXmlXsdValidateTarget(S, Pointer(Doc), Integer(Length(Doc)), T, Diags),
        'changed Lib: still validated');
      Check(LandrixGaebXmlXsdValidateTarget(S, Pointer(Doc), Integer(Length(Doc)), T, Diags),
        'changed Lib: validated again');
      CheckEquals(2, Diags.CountOf('GAEB-XSD-003'), 'changed Lib: GAEB-XSD-003 on both validations');
      Diags.Clear;
      Check(not S.Verify(Diags), 'changed Lib: Verify fails');
      CheckEquals(1, Diags.CountOf('GAEB-XSD-003'), 'changed Lib: Verify reports it once');
    finally
      S.Free;
    end;
    WriteBytes(Dir + 'pkg' + PathDelim + LibName, LibXsd);
    { the main schema twice; Verify reads the folder again }
    S := TLandrixGaebXmlXsdSchemas.Create(Dir);
    try
      Check(S.HasTarget(T), 'before the copy: found once');
      WriteBytes(Dir + 'other' + PathDelim + MainName, MainXsd);
      WriteBytes(Dir + 'other' + PathDelim + LibName, LibXsd);
      Diags.Clear;
      Check(not S.Verify(Diags), 'copy added later: Verify fails');
      CheckEquals(1, Diags.CountOf('GAEB-XSD-004'), 'copy added later: GAEB-XSD-004');
    finally
      S.Free;
    end;
    S := TLandrixGaebXmlXsdSchemas.Create(Dir);
    try
      Check(not S.HasTarget(T), 'twice: not a usable target');
      Check(RaisesGaebError(S, T, Doc), 'twice: validation raises');
      Diags.Clear;
      Check(not S.Verify(Diags), 'twice: Verify fails');
      CheckEquals(1, Diags.CountOf('GAEB-XSD-004'), 'twice: GAEB-XSD-004');
    finally
      S.Free;
    end;
    DeleteTree(Dir + 'other' + PathDelim);
    { the Lib file missing }
    DeleteFile(Dir + 'pkg' + PathDelim + LibName);
    S := TLandrixGaebXmlXsdSchemas.Create(Dir);
    try
      Check(S.HasTarget(T), 'no Lib: the main schema is found');
      Check(RaisesGaebError(S, T, Doc), 'no Lib: validation raises');
      Diags.Clear;
      Check(not S.Verify(Diags), 'no Lib: Verify fails');
      CheckEquals(1, Diags.CountOf('GAEB-XSD-004'), 'no Lib: GAEB-XSD-004');
    finally
      S.Free;
    end;
    { a schema document outside the folder is not read }
    DeleteTree(Dir);
    WriteBytes(Dir + 'outside.xsd', '<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" targetNamespace="' +
      Namespace + '"><xs:element name="GAEB"/></xs:schema>');
    WriteBytes(Dir + 'inner' + PathDelim + MainName, '<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema" ' +
      'targetNamespace="' + Namespace + '"><xs:include schemaLocation="../outside.xsd"/></xs:schema>');
    S := TLandrixGaebXmlXsdSchemas.Create(Dir + 'inner');
    try
      Check(S.HasTarget(T), 'outside: the main schema is found');
      Check(RaisesGaebError(S, T, Doc), 'outside: the include outside the folder is not read');
    finally
      S.Free;
    end;
  finally
    Diags.Free;
    DeleteTree(Dir);
  end;
end;

{ The schema sets of 3.0 and 3.1/2007-11 share the name GAEB_DA_XML.xsd:
  only the GAEB file of a version is taken, a changed one is not used. }
procedure TestApiFolderVersion3x;
var
  Dir, Src30, Src31, Src3109, Message: string;
  T30, T31, T31x84: TLandrixGaebTarget;
  Doc30, Doc31, Bid31: TLandrixXmlUtf8;
  S: TLandrixGaebXmlXsdSchemas;
  Diags: TLandrixGaebDiagnostics;
  G: TLandrixGaebXmlGAEB;
  Det: TLandrixGaebDetection;

  procedure CopySet(const ASrc, ADest: string; AWith84: Boolean);
  begin
    WriteBytes(ADest + 'GAEB_DA_XML.xsd', ReadFileBytes(ASrc + 'GAEB_DA_XML.xsd'));
    WriteBytes(ADest + 'xml.xsd', ReadFileBytes(ASrc + 'xml.xsd'));
    WriteBytes(ADest + 'xmldsig-core-schema.xsd', ReadFileBytes(ASrc + 'xmldsig-core-schema.xsd'));
    if AWith84 then
      WriteBytes(ADest + 'GAEB_DA_XML_84.xsd', ReadFileBytes(ASrc + 'GAEB_DA_XML_84.xsd'));
  end;

begin
  if not HaveSchemas then
    Exit;
  Dir := RepositoryRoot + 'build' + PathDelim + 'xsdtest3x' + PathDelim;
  Src30 := SchemaDir + 'XML-3.0' + PathDelim + 'Schema' + PathDelim;
  Src31 := SchemaDir + 'XML-3.1' + PathDelim + '2007-11-20' + PathDelim + 'Schema' + PathDelim;
  T30 := LandrixGaebTarget(gv30, ge2004_07, gp81);
  T31 := LandrixGaebTarget(gv31, ge2007_11, gp83);
  T31x84 := LandrixGaebTarget(gv31, ge2007_11, gp84);
  Src3109 := SchemaDir + 'XML-3.1' + PathDelim + '2009-12' + PathDelim + 'Schema' + PathDelim;
  Doc30 := Version3x('v30.x81');
  Doc31 := Request2007;
  Bid31 := Bid2007;
  Diags := TLandrixGaebDiagnostics.Create;
  try
    { an unwritable target is rejected before a schema is loaded: in an
      empty folder loading would fail with "not found" }
    DeleteTree(Dir);
    ForceDirectories(Dir);
    G := LandrixGaebXmlReadBuffer(Pointer(Doc31), Integer(Length(Doc31)), nil, Det);
    S := TLandrixGaebXmlXsdSchemas.Create(Dir);
    try
      Message := '';
      try
        LandrixGaebXmlXsdValidateModel(S, G, Det.Target, nil);
      except
        on E: ELandrixGaebError do
          Message := E.Message;
      end;
      Check(Pos('not supported for writing', Message) > 0, 'ValidateModel rejects 3.1 before loading: ' +
        Message);
    finally
      S.Free;
      G.Free;
    end;
    DeleteTree(Dir);
    CopySet(Src30, Dir + 'a' + PathDelim, False);
    CopySet(Src31, Dir + 'b' + PathDelim, True);
    S := TLandrixGaebXmlXsdSchemas.Create(Dir);
    try
      Check(S.HasTarget(T30) and S.HasTarget(T31) and S.HasTarget(T31x84), 'both sets found by their sums');
      Check(S.Verify(Diags), 'both sets: Verify passes: ' + Diags.ToText);
      Check(LandrixGaebXmlXsdValidateTarget(S, Pointer(Doc30), Integer(Length(Doc30)), T30, Diags),
        '3.0 against its schema: ' + Diags.ToText);
      Check(LandrixGaebXmlXsdValidateTarget(S, Pointer(Doc31), Integer(Length(Doc31)), T31, Diags),
        '3.1/2007-11 against its schema: ' + Diags.ToText);
      Check(LandrixGaebXmlXsdValidateTarget(S, Pointer(Bid31), Integer(Length(Bid31)), T31x84, Diags),
        '3.1/2007-11 X84 against its schema next to the main package: ' + Diags.ToText);
      { the schema of 3.0 serves every phase: loaded once, it is used for
        X83 too, although its files are gone now }
      DeleteTree(Dir + 'a' + PathDelim);
      Check(LandrixGaebXmlXsdValidateTarget(S, Pointer(Doc30), Integer(Length(Doc30)),
        LandrixGaebTarget(gv30, ge2004_07, gp83), Diags), '3.0 X83: the schema loaded for X81 is used');
      CheckEquals(0, Integer(Diags.Count), 'both sets: no diagnostic');
    finally
      S.Free;
    end;
    CopySet(Src30, Dir + 'a' + PathDelim, False);
    { a changed GAEB_DA_XML.xsd of 3.1/2007-11 is not used: never guessed }
    WriteBytes(Dir + 'b' + PathDelim + 'GAEB_DA_XML.xsd', ReadFileBytes(Src31 + 'GAEB_DA_XML.xsd') +
      '<!-- changed -->'#10);
    S := TLandrixGaebXmlXsdSchemas.Create(Dir);
    try
      Check(S.HasTarget(T30), 'changed 3.1 main: 3.0 still found');
      Check(not S.HasTarget(T31), 'changed 3.1 main: not used for 3.1');
      Check(S.HasTarget(T31x84), 'changed 3.1 main: the X84 schema is still found');
      Check(RaisesGaebError(S, T31, Doc31), 'changed 3.1 main: validation raises');
      Diags.Clear;
      Check(not S.Verify(Diags), 'changed 3.1 main: Verify fails');
      CheckEquals(1, Diags.CountOf('GAEB-XSD-003'), 'changed 3.1 main: reported once: ' + Diags.ToText);
    finally
      S.Free;
    end;
    CopySet(Src31, Dir + 'b' + PathDelim, True);
    { a changed xml.xsd: used with a warning }
    WriteBytes(Dir + 'b' + PathDelim + 'xml.xsd', ReadFileBytes(Src31 + 'xml.xsd') + '<!-- changed -->'#10);
    S := TLandrixGaebXmlXsdSchemas.Create(Dir);
    try
      Diags.Clear;
      Check(LandrixGaebXmlXsdValidateTarget(S, Pointer(Doc31), Integer(Length(Doc31)), T31, Diags),
        'changed xml.xsd: still validated');
      CheckEquals(1, Diags.CountOf('GAEB-XSD-003'), 'changed xml.xsd: GAEB-XSD-003');
    finally
      S.Free;
    end;
    CopySet(Src31, Dir + 'b' + PathDelim, True);
    { 2009-12 next to the files of 2007-11: its xmldsig differs }
    WriteBytes(Dir + 'b' + PathDelim + 'GAEB_DA_XML 3.1 2009-12.xsd',
      ReadFileBytes(Src3109 + 'GAEB_DA_XML 3.1 2009-12.xsd'));
    S := TLandrixGaebXmlXsdSchemas.Create(Dir);
    try
      Diags.Clear;
      Check(not S.Verify(Diags), 'mixed editions: Verify fails');
      CheckEquals(1, Diags.CountOf('GAEB-XSD-003'), 'mixed editions: the xmldsig of 2007-11 is reported: ' +
        Diags.ToText);
    finally
      S.Free;
    end;
    DeleteFile(Dir + 'b' + PathDelim + 'GAEB_DA_XML 3.1 2009-12.xsd');
    { the X84 package of 2007-11 alone: its imports are missing }
    WriteBytes(Dir + 'c' + PathDelim + 'GAEB_DA_XML_84.xsd', ReadFileBytes(Src31 + 'GAEB_DA_XML_84.xsd'));
    DeleteFile(Dir + 'b' + PathDelim + 'GAEB_DA_XML_84.xsd');
    S := TLandrixGaebXmlXsdSchemas.Create(Dir);
    try
      Check(S.HasTarget(T31x84), 'X84 alone: found');
      Check(RaisesGaebError(S, T31x84, Bid31), 'X84 alone: validation raises');
      Diags.Clear;
      Check(not S.Verify(Diags), 'X84 alone: Verify fails');
      CheckEquals(2, Diags.CountOf('GAEB-XSD-004'), 'X84 alone: xml.xsd and xmldsig missing: ' + Diags.ToText);
    finally
      S.Free;
    end;
    DeleteTree(Dir + 'c' + PathDelim);
    CopySet(Src31, Dir + 'b' + PathDelim, True);
    { xmldsig missing: the schema is incomplete }
    DeleteFile(Dir + 'b' + PathDelim + 'xmldsig-core-schema.xsd');
    S := TLandrixGaebXmlXsdSchemas.Create(Dir);
    try
      Check(RaisesGaebError(S, T31, Doc31), 'no xmldsig: validation raises');
      Diags.Clear;
      Check(not S.Verify(Diags), 'no xmldsig: Verify fails');
      CheckEquals(1, Diags.CountOf('GAEB-XSD-004'), 'no xmldsig: GAEB-XSD-004 once: ' + Diags.ToText);
    finally
      S.Free;
    end;
  finally
    Diags.Free;
    DeleteTree(Dir);
  end;
end;

procedure Register;
begin
  RegisterTest('Xsd.RuleCases', TestRuleCases);
  RegisterTest('Xsd.LegacyCases', TestLegacyCases);
  RegisterTest('Xsd.ProcessCases', TestProcessCases);
  RegisterTest('Xsd.CoverageCases', TestCoverageCases);
  RegisterTest('Xsd.WriterTargets', TestWriterTargets);
  RegisterTest('Xsd.Agreement', TestAgreement);
  RegisterTest('Xsd.Api.Model', TestApiModel);
  RegisterTest('Xsd.Api.Folder', TestApiFolder);
  RegisterTest('Xsd.Api.Version3x', TestApiVersion3x);
  RegisterTest('Xsd.Api.FolderVersion3x', TestApiFolderVersion3x);
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
  ApiSchemas.Free;
end.
