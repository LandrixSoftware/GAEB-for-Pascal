{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Validation against the original GAEB DA XML schemas (XSD) with the XML
  Schema validator of LandrixXml. The schemas are not part of the library:
  TLandrixGaebXmlXsdSchemas takes them from a folder of the user (the
  official packages from gaeb.de unpacked into it; tools/fetch-gaeb-xsd.ps1
  downloads and verifies them). Targets: GAEB DA XML 3.2 (2013-10) and 3.3
  (2019-11, 2021-05), phases 80 to 87.

  The XSD validation complements the check of LandrixGaebXmlCheck (content
  models generated from the same schemas, faster, part of every write); it
  does not replace it. Rule identifiers (messages never contain values of
  the document; XsdCode of the diagnostic holds the validator's code):
    GAEB-XSD-001  error    the document violates the schema
    GAEB-XSD-002  warning  part of the document was not validated (the
                           validator stopped after too many errors, or a
                           schema construct it does not support)
    GAEB-XSD-003  warning  a schema file differs from the official GAEB file
                           (validation still uses it)
    GAEB-XSD-004  error    Verify: a schema file is missing or found twice
  A missing or unloadable schema raises ELandrixGaebError: False always
  means "the document is invalid". Positions are those of the validator
  (right after the tag where the error is found), Offset is -1; for
  ValidateModel and ValidateBill they refer to the written output.

  The schema folder is trusted input of the caller; schema documents are
  only read from inside it. A TLandrixGaebXmlXsdSchemas loads the schema of
  a target on first use and keeps it; use one object per thread (or
  serialize the calls).

  DE: Pruefung gegen die originalen GAEB-DA-XML-Schemas (XSD) mit dem
  XML-Schema-Validator von LandrixXml. Die Schemas gehoeren nicht zur
  Bibliothek: TLandrixGaebXmlXsdSchemas nimmt sie aus einem Ordner des
  Nutzers (die offiziellen Pakete von gaeb.de darin entpackt;
  tools/fetch-gaeb-xsd.ps1 laedt und prueft sie). Ziele: GAEB DA XML 3.2
  (2013-10) und 3.3 (2019-11, 2021-05), Phasen 80 bis 87.

  Die XSD-Pruefung ergaenzt die Pruefung von LandrixGaebXmlCheck
  (Inhaltsmodelle aus denselben Schemas erzeugt, schneller, Teil jedes
  Schreibens); sie ersetzt sie nicht. Regelkennungen (Meldungen enthalten
  nie Werte des Dokuments; XsdCode der Meldung haelt den Code des
  Validators):
    GAEB-XSD-001  Fehler   das Dokument verletzt das Schema
    GAEB-XSD-002  Warnung  ein Teil des Dokuments wurde nicht geprueft (der
                           Validator hat nach zu vielen Fehlern aufgehoert,
                           oder ein Schemakonstrukt, das er nicht kennt)
    GAEB-XSD-003  Warnung  eine Schemadatei weicht von der offiziellen
                           GAEB-Datei ab (geprueft wird trotzdem damit)
    GAEB-XSD-004  Fehler   Verify: eine Schemadatei fehlt oder liegt doppelt
                           vor
  Ein fehlendes oder nicht ladbares Schema loest ELandrixGaebError aus:
  False heisst immer "das Dokument ist ungueltig". Positionen sind die des
  Validators (direkt nach dem Tag, an dem der Fehler auffaellt), Offset ist
  -1; bei ValidateModel und ValidateBill beziehen sie sich auf die
  geschriebene Ausgabe.

  Der Schemaordner ist vertrauenswuerdige Eingabe des Aufrufers;
  Schemadokumente werden nur aus ihm gelesen. Ein
  TLandrixGaebXmlXsdSchemas laedt das Schema eines Ziels bei der ersten
  Verwendung und behaelt es; ein Objekt je Thread verwenden (oder die
  Aufrufe serialisieren). }

{ API: stable. Covered by semantic versioning from release 1.0 on.
  DE: API: stabil. Ab Version 1.0 durch die semantische Versionierung
  abgedeckt. }

unit LandrixGaebXmlXsd;

{$I LandrixGaeb.inc}

interface

uses
  SysUtils,
  Classes,
  LandrixXmlBase,
  LandrixGaebTypes,
  LandrixGaebDiagnostics,
  LandrixGaebDetect,
  LandrixGaebXmlModel,
  LandrixGaebBoQ;

type
  { The GAEB schemas from a folder of the user. A main schema
    (GAEB_DA_XML_<DP>_<version>_<edition>.xsd) is searched by its file
    name anywhere below the folder (eight levels deep, not through links);
    its Lib file must lie next to it, as in the official packages. A main
    schema found twice is an error. The folder is trusted: links inside it
    are not checked when a schema refers to another file.
    DE: Die GAEB-Schemas aus einem Ordner des Nutzers. Ein Hauptschema
    (GAEB_DA_XML_<DP>_<Version>_<Ausgabe>.xsd) wird ueber seinen Dateinamen
    irgendwo unterhalb des Ordners gesucht (acht Ebenen tief, nicht ueber
    Links); seine Lib-Datei muss daneben liegen, wie in den offiziellen
    Paketen. Ein doppelt gefundenes Hauptschema ist ein Fehler. Der Ordner
    ist vertrauenswuerdig: Links in ihm werden nicht geprueft, wenn ein
    Schema auf eine andere Datei verweist. }
  TLandrixGaebXmlXsdSchemas = class(TObject)
  private
    FFolder: string;
    FIndexed: Boolean;
    FIndex: TStringList;
    FResolver: TObject;
    FSchemas: array of TObject;
    FNotes: array of string;
    procedure BuildIndex;
    procedure Scan(const ARel: string; ADepth: Integer);
    procedure Entries(const AName: string; AList: TStrings);
    function Schema(const ATarget: TLandrixGaebTarget): TObject;
    function ChecksumNote(const ARel: string; const ATarget: TLandrixGaebTarget): string;
  public
    { AFolder must exist (ELandrixGaebError otherwise); nothing is read
      before the first use.
      DE: AFolder muss existieren (sonst ELandrixGaebError); vor der ersten
      Verwendung wird nichts gelesen. }
    constructor Create(const AFolder: string);
    destructor Destroy; override;
    { True if the folder holds the main schema of ATarget exactly once and
      the library validates that target. It does not load the schema.
      DE: True, wenn der Ordner das Hauptschema von ATarget genau einmal
      enthaelt und die Bibliothek dieses Ziel prueft. Laedt das Schema
      nicht. }
    function HasTarget(const ATarget: TLandrixGaebTarget): Boolean;
    { Reads the folder again and compares every schema file of the targets
      found with the SHA-256 of the official GAEB file: GAEB-XSD-003 for a differing file,
      GAEB-XSD-004 for a missing Lib file, a main schema found twice or a
      folder without any. True if all match. ADiagnostics may be nil.
      DE: Liest den Ordner neu ein und vergleicht jede Schemadatei der
      gefundenen Ziele mit der SHA-256 der offiziellen GAEB-Datei: GAEB-XSD-003 fuer eine abweichende Datei,
      GAEB-XSD-004 fuer eine fehlende Lib-Datei, ein doppelt gefundenes
      Hauptschema oder einen Ordner ohne Schema. True, wenn alles stimmt.
      ADiagnostics darf nil sein. }
    function Verify(ADiagnostics: TLandrixGaebDiagnostics): Boolean;
    { The folder as an absolute path with trailing delimiter.
      DE: Der Ordner als absoluter Pfad mit abschliessendem Trenner. }
    property Folder: string read FFolder;
  end;

{ Validates a document in a buffer against the schema of the target it
  declares (detected as by the reader). True if the document is valid.
  Raises ELandrixGaebError for input that is not GAEB DA XML, a target
  without schema validation and a schema that is missing or cannot be
  loaded, ELandrixXmlError for XML that is not well-formed. ADiagnostics
  may be nil.
  DE: Prueft ein Dokument in einem Puffer gegen das Schema des Ziels, das
  es angibt (erkannt wie beim Leser). True, wenn das Dokument gueltig ist.
  Loest ELandrixGaebError aus fuer Eingaben, die kein GAEB DA XML sind,
  Ziele ohne Schemapruefung und ein fehlendes oder nicht ladbares Schema,
  ELandrixXmlError fuer nicht wohlgeformtes XML. ADiagnostics darf nil
  sein. }
function LandrixGaebXmlXsdValidateBuffer(ASchemas: TLandrixGaebXmlXsdSchemas; Buffer: Pointer;
  Size: Integer; ADiagnostics: TLandrixGaebDiagnostics; out ADetection: TLandrixGaebDetection): Boolean;

{ Validates a stream (current position to the end). AMaxSize <= 0 means
  LandrixGaebDefaultMaxSize.
  DE: Prueft einen Stream (aktuelle Position bis zum Ende). AMaxSize <= 0
  bedeutet LandrixGaebDefaultMaxSize. }
function LandrixGaebXmlXsdValidateStream(ASchemas: TLandrixGaebXmlXsdSchemas; AStream: TStream;
  ADiagnostics: TLandrixGaebDiagnostics; AMaxSize: Int64; out ADetection: TLandrixGaebDetection): Boolean;

{ Validates a file. DE: Prueft eine Datei. }
function LandrixGaebXmlXsdValidateFile(ASchemas: TLandrixGaebXmlXsdSchemas; const AFileName: string;
  ADiagnostics: TLandrixGaebDiagnostics; AMaxSize: Int64; out ADetection: TLandrixGaebDetection): Boolean;

{ Validates a document in a buffer against the schema of ATarget without
  detection (for output of the writer).
  DE: Prueft ein Dokument in einem Puffer ohne Erkennung gegen das Schema
  von ATarget (fuer Ausgaben des Schreibers). }
function LandrixGaebXmlXsdValidateTarget(ASchemas: TLandrixGaebXmlXsdSchemas; Buffer: Pointer;
  Size: Integer; const ATarget: TLandrixGaebTarget; ADiagnostics: TLandrixGaebDiagnostics): Boolean;

{ Validates a model for ATarget: writes it (mode gwmNormal, without the
  check of LandrixGaebXmlCheck, nothing is raised for problems) and
  validates the output. True if neither the writer nor the validation found
  an error. Raises like LandrixGaebXmlWriteCollect for a target that cannot
  be written (3.3/2019-11).
  DE: Prueft ein Modell fuer ATarget: schreibt es (Modus gwmNormal, ohne
  die Pruefung von LandrixGaebXmlCheck, fuer Probleme wird nichts
  ausgeloest) und prueft die Ausgabe. True, wenn weder der Schreiber noch
  die Pruefung einen Fehler gefunden hat. Loest wie
  LandrixGaebXmlWriteCollect aus fuer ein Ziel, das nicht geschrieben werden
  kann (3.3/2019-11). }
function LandrixGaebXmlXsdValidateModel(ASchemas: TLandrixGaebXmlXsdSchemas; ADocument: TLandrixGaebXmlGAEB;
  const ATarget: TLandrixGaebTarget; ADiagnostics: TLandrixGaebDiagnostics): Boolean;

{ Validates the bill as SaveToFile would write it (OutputTarget,
  WriteOptions without Check), before saving; it does not save. True if
  the output is valid and the writer would not abort in the mode of
  WriteOptions (gwmStrict: no error or warning, gwmNormal: no error).
  DE: Prueft das LV so, wie SaveToFile es schreiben wuerde (OutputTarget,
  WriteOptions ohne Check), vor dem Speichern; speichert nicht. True, wenn
  die Ausgabe gueltig ist und der Schreiber im Modus von WriteOptions nicht
  abbrechen wuerde (gwmStrict: kein Fehler und keine Warnung, gwmNormal:
  kein Fehler). }
function LandrixGaebXmlXsdValidateBill(ASchemas: TLandrixGaebXmlXsdSchemas;
  ABill: TLandrixGaebBillOfQuantities; ADiagnostics: TLandrixGaebDiagnostics): Boolean;

implementation

uses
  LandrixXmlReader,
  LandrixXmlSha256,
  LandrixXmlXsdSchema,
  LandrixXmlXsdSchemaLoader,
  LandrixXmlXsdValidator,
  LandrixGaebXmlWriter,
  LandrixGaebXmlXsdSums;

const
  { the published targets: three editions, eight phases }
  SlotCount = 24;
  MaxScanDepth = 8;
  { the attribute of links, skipped by the scan: a reparse point (junction,
    symbolic link) on Windows, faSymLink of Free Pascal on Unix (reported
    only when the search asks for it) }
  LinkAttributes = $400;

type
  { Reads schema documents only from inside the schema folder. }
  TFolderResolver = class(TLandrixXmlXsdResolver)
  private
    FFolder: string;
  public
    constructor CreateFolder(const AFolder: string);
    function Resolve(const BaseFile: string; const Location, NamespaceUri: TLandrixXmlUtf8;
      IsImport: Boolean): string; override;
  end;

function StartsWith(const S, APrefix: string): Boolean;
begin
  Result := Copy(S, 1, Length(APrefix)) = APrefix;
end;

constructor TFolderResolver.CreateFolder(const AFolder: string);
begin
  inherited Create;
  FFolder := AFolder;
end;

function TFolderResolver.Resolve(const BaseFile: string; const Location, NamespaceUri: TLandrixXmlUtf8;
  IsImport: Boolean): string;
begin
  Result := inherited Resolve(BaseFile, Location, NamespaceUri, IsImport);
  if (Result <> '') and not SameFileName(Copy(ExpandFileName(Result), 1, Length(FFolder)), FFolder) then
    Result := '';
end;

{ ---- targets ---- }

{ 0..23 for the published targets, -1 otherwise. }
function TargetSlot(const ATarget: TLandrixGaebTarget): Integer;
var
  E, P: Integer;
begin
  Result := -1;
  if (ATarget.Version = gv32) and (ATarget.Edition = ge2013_10) then
    E := 0
  else if (ATarget.Version = gv33) and (ATarget.Edition = ge2019_11) then
    E := 1
  else if (ATarget.Version = gv33) and (ATarget.Edition = ge2021_05) then
    E := 2
  else
    Exit;
  case ATarget.Phase of
    gp80: P := 0;
    gp81: P := 1;
    gp82: P := 2;
    gp83: P := 3;
    gp84: P := 4;
    gp85: P := 5;
    gp86: P := 6;
    gp87: P := 7;
  else
    Exit;
  end;
  Result := E * 8 + P;
end;

function SlotTarget(ASlot: Integer): TLandrixGaebTarget;
const
  Phases: array[0..7] of TLandrixGaebPhase = (gp80, gp81, gp82, gp83, gp84, gp85, gp86, gp87);
begin
  case ASlot div 8 of
    0: Result := LandrixGaebTarget(gv32, ge2013_10, Phases[ASlot mod 8]);
    1: Result := LandrixGaebTarget(gv33, ge2019_11, Phases[ASlot mod 8]);
  else
    Result := LandrixGaebTarget(gv33, ge2021_05, Phases[ASlot mod 8]);
  end;
end;

function VersionText(const ATarget: TLandrixGaebTarget): string;
begin
  Result := LandrixXmlUtf8ToString(LandrixGaebVersionToText(ATarget.Version));
end;

function EditionText(const ATarget: TLandrixGaebTarget): string;
begin
  Result := LandrixXmlUtf8ToString(LandrixGaebEditionToText(ATarget.Edition));
end;

function TargetText(const ATarget: TLandrixGaebTarget): string;
begin
  Result := 'GAEB DA XML ' + VersionText(ATarget) + ' (' + EditionText(ATarget) + '), DA ' +
    LandrixXmlUtf8ToString(LandrixGaebPhaseToDP(ATarget.Phase));
end;

function MainFileName(const ATarget: TLandrixGaebTarget): string;
begin
  Result := 'GAEB_DA_XML_' + LandrixXmlUtf8ToString(LandrixGaebPhaseToDP(ATarget.Phase)) + '_' +
    VersionText(ATarget) + '_' + EditionText(ATarget) + '.xsd';
end;

function LibFileName(const ATarget: TLandrixGaebTarget): string;
begin
  Result := 'GAEB_DA_XML_Lib_' + VersionText(ATarget) + '_' + EditionText(ATarget) + '.xsd';
end;

{ ---- checksums ---- }

{ The official SHA-256 of a schema file name, '' if unknown. }
function OfficialSum(const AName: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to LandrixGaebXsdSumCount - 1 do
    if LandrixGaebXsdSumNames[I] = AName then
    begin
      Result := LandrixGaebXsdSumValues[I];
      Exit;
    end;
end;

{ The SHA-256 of the file ARel below AFolder; a file that cannot be read
  raises ELandrixGaebError naming ARel. }
function FileSum(const AFolder, ARel: string): string;
var
  Stream: TFileStream;
  Data: AnsiString;
begin
  Data := '';
  try
    Stream := TFileStream.Create(AFolder + ARel, fmOpenRead or fmShareDenyWrite);
    try
      SetLength(Data, Integer(Stream.Size));
      if Length(Data) > 0 then
        Stream.ReadBuffer(Data[1], Length(Data));
    finally
      Stream.Free;
    end;
  except
    on EStreamError do
      raise ELandrixGaebError.Create('schema file cannot be read: ' + ARel);
    on EInOutError do
      raise ELandrixGaebError.Create('schema file cannot be read: ' + ARel);
  end;
  if Length(Data) = 0 then
    { no byte is read: any variable will do as the buffer }
    Result := LandrixXmlSha256Hex(Data, 0)
  else
    Result := LandrixXmlSha256Hex(Data[1], Length(Data));
end;

{ ---- TLandrixGaebXmlXsdSchemas ---- }

constructor TLandrixGaebXmlXsdSchemas.Create(const AFolder: string);
begin
  inherited Create;
  if (AFolder = '') or not DirectoryExists(AFolder) then
    raise ELandrixGaebError.Create('schema folder not found: ' + AFolder);
  FFolder := IncludeTrailingPathDelimiter(ExpandFileName(AFolder));
  FIndex := TStringList.Create;
  FResolver := TFolderResolver.CreateFolder(FFolder);
  SetLength(FSchemas, SlotCount);
  SetLength(FNotes, SlotCount);
end;

destructor TLandrixGaebXmlXsdSchemas.Destroy;
var
  I: Integer;
begin
  for I := 0 to Integer(Length(FSchemas)) - 1 do
    FSchemas[I].Free;
  FResolver.Free;
  FIndex.Free;
  inherited Destroy;
end;

procedure TLandrixGaebXmlXsdSchemas.Scan(const ARel: string; ADepth: Integer);
var
  SR: TSearchRec;
begin
  if FindFirst(FFolder + ARel + '*', faAnyFile or LinkAttributes, SR) = 0 then
  try
    repeat
      if (SR.Name = '.') or (SR.Name = '..') or ((SR.Attr and LinkAttributes) <> 0) then
        Continue;
      if (SR.Attr and faDirectory) <> 0 then
      begin
        if ADepth < MaxScanDepth then
          Scan(ARel + SR.Name + PathDelim, ADepth + 1);
      end
      else if OfficialSum(SR.Name) <> '' then
        FIndex.Add(SR.Name + '=' + ARel + SR.Name);
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

procedure TLandrixGaebXmlXsdSchemas.BuildIndex;
begin
  if FIndexed then
    Exit;
  FIndex.Clear;
  Scan('', 1);
  FIndexed := True;
end;

{ The paths relative to Folder of the files named AName, sorted. }
procedure TLandrixGaebXmlXsdSchemas.Entries(const AName: string; AList: TStrings);
var
  I: Integer;
  Sorted: TStringList;
begin
  Sorted := TStringList.Create;
  try
    for I := 0 to FIndex.Count - 1 do
      if FIndex.Names[I] = AName then
        Sorted.Add(Copy(FIndex[I], Length(AName) + 2, MaxInt));
    Sorted.Sort;
    AList.Assign(Sorted);
  finally
    Sorted.Free;
  end;
end;

function TLandrixGaebXmlXsdSchemas.HasTarget(const ATarget: TLandrixGaebTarget): Boolean;
var
  Paths: TStringList;
begin
  Result := False;
  if TargetSlot(ATarget) < 0 then
    Exit;
  BuildIndex;
  Paths := TStringList.Create;
  try
    Entries(MainFileName(ATarget), Paths);
    Result := Paths.Count = 1;
  finally
    Paths.Free;
  end;
end;

{ A note for GAEB-XSD-003 if the main schema at ARel or its Lib file
  differs from the official file, '' otherwise. }
function TLandrixGaebXmlXsdSchemas.ChecksumNote(const ARel: string; const ATarget: TLandrixGaebTarget): string;
var
  LibRel: string;
begin
  Result := '';
  if FileSum(FFolder, ARel) <> OfficialSum(MainFileName(ATarget)) then
    Result := ARel;
  LibRel := ExtractFilePath(ARel) + LibFileName(ATarget);
  if FileExists(FFolder + LibRel) and (FileSum(FFolder, LibRel) <> OfficialSum(LibFileName(ATarget))) then
  begin
    if Result <> '' then
      Result := Result + ', ';
    Result := Result + LibRel;
  end;
  if Result <> '' then
    Result := 'schema file differs from the official GAEB file: ' + Result;
end;

function TLandrixGaebXmlXsdSchemas.Schema(const ATarget: TLandrixGaebTarget): TObject;
var
  Slot: Integer;
  Paths: TStringList;
  Main, Rel, Note: string;
  Loaded: TLandrixXmlXsdSchemaSet;
begin
  Slot := TargetSlot(ATarget);
  if Slot < 0 then
    raise ELandrixGaebError.Create('no XSD validation for ' + TargetText(ATarget));
  if FSchemas[Slot] = nil then
  begin
    BuildIndex;
    Main := MainFileName(ATarget);
    Paths := TStringList.Create;
    try
      Entries(Main, Paths);
      if Paths.Count = 0 then
        raise ELandrixGaebError.Create('schema ' + Main + ' for ' + TargetText(ATarget) +
          ' not found in the schema folder');
      if Paths.Count > 1 then
        raise ELandrixGaebError.Create('schema ' + Main + ' found more than once in the schema folder: ' +
          Paths[0] + ', ' + Paths[1]);
      Rel := Paths[0];
    finally
      Paths.Free;
    end;
    try
      Loaded := LandrixXmlXsdLoadSchema(FFolder + Rel, TLandrixXmlXsdResolver(FResolver));
    except
      on E: ELandrixXmlXsdSchemaError do
        raise ELandrixGaebError.Create('schema ' + Rel + ' cannot be loaded: ' +
          ExtractFileName(E.SchemaFile) + ' line ' + IntToStr(E.Line) + ': ' + E.ConstraintCode);
      on E: ELandrixXmlError do
        raise ELandrixGaebError.Create('schema ' + Rel + ' cannot be loaded: not well-formed at line ' +
          IntToStr(E.Line) + ', column ' + IntToStr(E.Column));
      on EStreamError do
        raise ELandrixGaebError.Create('schema ' + Rel + ' cannot be loaded: a schema file cannot be read');
      on EInOutError do
        raise ELandrixGaebError.Create('schema ' + Rel + ' cannot be loaded: a schema file cannot be read');
    end;
    try
      if Loaded.Warnings.Count > 0 then
        raise ELandrixGaebError.Create('schema ' + Rel +
          ' is incomplete: a schema document it refers to is not found inside the schema folder');
      Note := ChecksumNote(Rel, ATarget);
    except
      Loaded.Free;
      raise;
    end;
    { only a schema whose checksums were computed is kept }
    FSchemas[Slot] := Loaded;
    FNotes[Slot] := Note;
  end;
  Result := FSchemas[Slot];
end;

function TLandrixGaebXmlXsdSchemas.Verify(ADiagnostics: TLandrixGaebDiagnostics): Boolean;
var
  Ok: Boolean;
  Slot, Found: Integer;
  T: TLandrixGaebTarget;
  Paths, Reported: TStringList;
  Main, Rel, LibRel: string;

  procedure Report(const ARuleId: string; ASeverity: TLandrixGaebSeverity; const AMessage: string);
  begin
    Ok := False;
    if ADiagnostics <> nil then
      ADiagnostics.AddDiagnostic(ARuleId, ASeverity, AMessage);
  end;

  procedure CheckSum(const ARelFile, AName: string);
  begin
    if Reported.IndexOf(ARelFile) >= 0 then
      Exit;
    Reported.Add(ARelFile);
    if FileSum(FFolder, ARelFile) <> OfficialSum(AName) then
      Report('GAEB-XSD-003', gsWarning, 'schema file differs from the official GAEB file: ' + ARelFile);
  end;

begin
  Ok := True;
  { the folder as it is now, not as it was at the first use }
  FIndexed := False;
  BuildIndex;
  Found := 0;
  Paths := TStringList.Create;
  Reported := TStringList.Create;
  try
    for Slot := 0 to SlotCount - 1 do
    begin
      T := SlotTarget(Slot);
      Main := MainFileName(T);
      Entries(Main, Paths);
      if Paths.Count = 0 then
        Continue;
      Inc(Found);
      if Paths.Count > 1 then
      begin
        Report('GAEB-XSD-004', gsError, 'schema ' + Main + ' found more than once in the schema folder: ' +
          Paths[0] + ', ' + Paths[1]);
        Continue;
      end;
      Rel := Paths[0];
      CheckSum(Rel, Main);
      LibRel := ExtractFilePath(Rel) + LibFileName(T);
      if not FileExists(FFolder + LibRel) then
      begin
        if Reported.IndexOf(LibRel) < 0 then
        begin
          Reported.Add(LibRel);
          Report('GAEB-XSD-004', gsError, 'schema file missing: ' + LibRel + ' (needed by ' + Rel + ')');
        end;
      end
      else
        CheckSum(LibRel, LibFileName(T));
    end;
    if Found = 0 then
      Report('GAEB-XSD-004', gsError, 'no GAEB DA XML schema found in the schema folder');
  finally
    Reported.Free;
    Paths.Free;
  end;
  Result := Ok;
end;

{ ---- validation ---- }

{ A text without values for a validator code. }
function XsdText(const ACode: string): string;
begin
  if ACode = 'cvc-complex-type.2.4.a' then
    Result := 'element not allowed at this position'
  else if ACode = 'cvc-complex-type.2.4.b' then
    Result := 'content incomplete: a required child element is missing'
  else if ACode = 'cvc-complex-type.2.4.c' then
    Result := 'element not declared'
  else if ACode = 'cvc-complex-type.2.4.d' then
    Result := 'no child element allowed at this position'
  else if ACode = 'cvc-complex-type.2.1' then
    Result := 'element must be empty'
  else if ACode = 'cvc-complex-type.2.2' then
    Result := 'invalid content: no child elements allowed, or the simple content is not valid'
  else if ACode = 'cvc-complex-type.2.3' then
    Result := 'character data not allowed in element-only content'
  else if ACode = 'cvc-complex-type.3.1' then
    Result := 'attribute value differs from its fixed value'
  else if ACode = 'cvc-complex-type.3.2.2' then
    Result := 'attribute not allowed'
  else if ACode = 'cvc-complex-type.4' then
    Result := 'required attribute missing'
  else if StartsWith(ACode, 'cvc-complex-type.5') then
    Result := 'more than one ID attribute'
  else if (ACode = 'cvc-elt.1') or (ACode = 'cvc-elt.1.a') then
    Result := 'no declaration for this element (wrong namespace or element name)'
  else if StartsWith(ACode, 'cvc-elt.') then
    Result := 'element declaration constraint violated'
  else if StartsWith(ACode, 'cvc-type.') then
    Result := 'invalid element value or type'
  else if ACode = 'cvc-attribute.3' then
    Result := 'invalid attribute value'
  else if ACode = 'cvc-attribute.4' then
    Result := 'attribute value differs from its fixed value'
  else if ACode = 'cvc-id.1' then
    Result := 'reference to an ID that does not exist'
  else if ACode = 'cvc-id.2' then
    Result := 'ID used more than once'
  else if StartsWith(ACode, 'cvc-id.') or StartsWith(ACode, 'cvc-identity-constraint') or
    StartsWith(ACode, 'KeyRef') then
    Result := 'identity constraint (unique, key or key reference) violated'
  else if ACode = 'cvc-pattern-valid' then
    Result := 'value does not match the required pattern'
  else if ACode = 'cvc-enumeration-valid' then
    Result := 'value is not one of the allowed values'
  else if (ACode = 'cvc-length-valid') or (ACode = 'cvc-minLength-valid') or (ACode = 'cvc-maxLength-valid') then
    Result := 'value length outside the allowed range'
  else if (ACode = 'cvc-totalDigits-valid') or (ACode = 'cvc-fractionDigits-valid') then
    Result := 'value has too many digits'
  else if (ACode = 'cvc-minInclusive-valid') or (ACode = 'cvc-maxInclusive-valid') or
    (ACode = 'cvc-minExclusive-valid') or (ACode = 'cvc-maxExclusive-valid') then
    Result := 'value outside the allowed range'
  else if StartsWith(ACode, 'cvc-datatype-valid') then
    Result := 'value is not valid for its data type'
  else
    Result := 'schema violation';
end;

function ValidateLoaded(ASchemas: TLandrixGaebXmlXsdSchemas; Buffer: Pointer; Size: Integer;
  const ATarget: TLandrixGaebTarget; ADiagnostics: TLandrixGaebDiagnostics): Boolean;
var
  SchemaSet: TLandrixXmlXsdSchemaSet;
  Reader: TLandrixXmlReader;
  Validator: TLandrixXmlXsdValidator;
  Error: TLandrixXmlXsdValidationError;
  I, Errors: Integer;
  Note: string;
begin
  if ASchemas = nil then
    raise ELandrixGaebError.Create('no schemas given');
  SchemaSet := TLandrixXmlXsdSchemaSet(ASchemas.Schema(ATarget));
  Note := ASchemas.FNotes[TargetSlot(ATarget)];
  if (Note <> '') and (ADiagnostics <> nil) then
    ADiagnostics.AddDiagnostic('GAEB-XSD-003', gsWarning, Note);
  Errors := 0;
  Reader := TLandrixXmlReader.Create;
  try
    Validator := TLandrixXmlXsdValidator.Create(SchemaSet);
    try
      if Size > 0 then
        Reader.LoadFromBuffer(Buffer^, Size)
      else
        Reader.LoadFromUtf8('');
      Validator.ValidateReader(Reader);
      for I := 0 to Validator.ErrorCount - 1 do
      begin
        Error := Validator.Errors[I];
        if Error.Code = 'unsupported' then
        begin
          if ADiagnostics <> nil then
            ADiagnostics.AddAt('GAEB-XSD-002', gsWarning, TLandrixGaebString(LandrixXmlUtf8ToWide(Error.Path)),
              Error.Line, Error.Column, -1, 'schema construct not supported by the validator; ' +
              'this part was not validated (' + Error.Code + ')').XsdCode := Error.Code;
        end
        else
        begin
          Inc(Errors);
          if ADiagnostics <> nil then
            ADiagnostics.AddAt('GAEB-XSD-001', gsError, TLandrixGaebString(LandrixXmlUtf8ToWide(Error.Path)),
              Error.Line, Error.Column, -1, XsdText(Error.Code) + ' (' + Error.Code + ')').XsdCode := Error.Code;
        end;
      end;
      if Validator.Truncated and (ADiagnostics <> nil) then
        ADiagnostics.AddDiagnostic('GAEB-XSD-002', gsWarning, 'validation stopped after ' +
          IntToStr(Validator.ErrorCount) + ' errors; the rest of the document was not validated');
    finally
      Validator.Free;
    end;
  finally
    Reader.Free;
  end;
  Result := Errors = 0;
end;

function RejectMessage(ADiagnostics: TLandrixGaebDiagnostics; AFirst: Integer): string;
var
  I: TLandrixGaebListIndex;
begin
  Result := 'input is not a readable GAEB DA XML document';
  for I := AFirst to ADiagnostics.Count - 1 do
    if ADiagnostics[I].Severity >= gsError then
    begin
      Result := Result + ': [' + ADiagnostics[I].RuleId + '] ' + ADiagnostics[I].Message;
      Exit;
    end;
end;

function LandrixGaebXmlXsdValidateBuffer(ASchemas: TLandrixGaebXmlXsdSchemas; Buffer: Pointer;
  Size: Integer; ADiagnostics: TLandrixGaebDiagnostics; out ADetection: TLandrixGaebDetection): Boolean;
var
  Diags: TLandrixGaebDiagnostics;
  First: Integer;
begin
  Diags := ADiagnostics;
  if Diags = nil then
    Diags := TLandrixGaebDiagnostics.Create;
  try
    First := Integer(Diags.Count);
    ADetection := LandrixGaebDetectBuffer(Buffer, Size, False, Diags);
    if not ADetection.Accepted or (ADetection.Format <> gfXml) then
      raise ELandrixGaebError.Create(RejectMessage(Diags, First));
  finally
    if ADiagnostics = nil then
      Diags.Free;
  end;
  Result := ValidateLoaded(ASchemas, Buffer, Size, ADetection.Target, ADiagnostics);
end;

function LandrixGaebXmlXsdValidateStream(ASchemas: TLandrixGaebXmlXsdSchemas; AStream: TStream;
  ADiagnostics: TLandrixGaebDiagnostics; AMaxSize: Int64; out ADetection: TLandrixGaebDetection): Boolean;
var
  Remaining: Int64;
  Buffer: AnsiString;
  Count: Integer;
begin
  if AMaxSize <= 0 then
    AMaxSize := LandrixGaebDefaultMaxSize;
  if AMaxSize > MaxInt then
    AMaxSize := MaxInt;
  Remaining := AStream.Size - AStream.Position;
  if Remaining > AMaxSize then
    raise ELandrixGaebError.Create('input of ' + IntToStr(Remaining) +
      ' bytes exceeds the size limit of ' + IntToStr(AMaxSize) + ' bytes');
  Count := Integer(Remaining);
  Buffer := '';
  SetLength(Buffer, Count);
  if Count > 0 then
    AStream.ReadBuffer(Buffer[1], Count);
  Result := LandrixGaebXmlXsdValidateBuffer(ASchemas, Pointer(Buffer), Count, ADiagnostics, ADetection);
end;

function LandrixGaebXmlXsdValidateFile(ASchemas: TLandrixGaebXmlXsdSchemas; const AFileName: string;
  ADiagnostics: TLandrixGaebDiagnostics; AMaxSize: Int64; out ADetection: TLandrixGaebDetection): Boolean;
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    Result := LandrixGaebXmlXsdValidateStream(ASchemas, Stream, ADiagnostics, AMaxSize, ADetection);
  finally
    Stream.Free;
  end;
end;

function LandrixGaebXmlXsdValidateTarget(ASchemas: TLandrixGaebXmlXsdSchemas; Buffer: Pointer;
  Size: Integer; const ATarget: TLandrixGaebTarget; ADiagnostics: TLandrixGaebDiagnostics): Boolean;
begin
  Result := ValidateLoaded(ASchemas, Buffer, Size, ATarget, ADiagnostics);
end;

function LandrixGaebXmlXsdValidateModel(ASchemas: TLandrixGaebXmlXsdSchemas; ADocument: TLandrixGaebXmlGAEB;
  const ATarget: TLandrixGaebTarget; ADiagnostics: TLandrixGaebDiagnostics): Boolean;
var
  Options: TLandrixGaebXmlWriteOptions;
  Output: TLandrixXmlUtf8;
  Errors, Warnings: Integer;
  Valid: Boolean;
begin
  if ASchemas = nil then
    raise ELandrixGaebError.Create('no schemas given');
  { load the schema first: a missing schema raises before any writing }
  ASchemas.Schema(ATarget);
  Options := LandrixGaebXmlDefaultWriteOptions;
  Options.Mode := gwmNormal;
  Options.Check := False;
  Output := LandrixGaebXmlWriteCollect(ADocument, ATarget, Options, ADiagnostics, Errors, Warnings);
  Valid := ValidateLoaded(ASchemas, Pointer(Output), Length(Output), ATarget, ADiagnostics);
  Result := Valid and (Errors = 0);
end;

function LandrixGaebXmlXsdValidateBill(ASchemas: TLandrixGaebXmlXsdSchemas;
  ABill: TLandrixGaebBillOfQuantities; ADiagnostics: TLandrixGaebDiagnostics): Boolean;
var
  Options: TLandrixGaebXmlWriteOptions;
  Target: TLandrixGaebTarget;
  Output: TLandrixXmlUtf8;
  Errors, Warnings: Integer;
  Valid, Writable: Boolean;
begin
  if ASchemas = nil then
    raise ELandrixGaebError.Create('no schemas given');
  Target := ABill.OutputTarget;
  ASchemas.Schema(Target);
  Options := ABill.WriteOptions;
  Options.Check := False;
  Output := LandrixGaebXmlWriteCollect(ABill.Document, Target, Options, ADiagnostics, Errors, Warnings);
  Valid := ValidateLoaded(ASchemas, Pointer(Output), Length(Output), Target, ADiagnostics);
  case Options.Mode of
    gwmStrict: Writable := (Errors = 0) and (Warnings = 0);
    gwmNormal: Writable := Errors = 0;
  else
    Writable := True;
  end;
  Result := Valid and Writable;
end;

end.
