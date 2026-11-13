{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Format-faithful parser for GAEB DA 2000 files: objects (#begin[Key] ...
  #end[Key]) and elements ([Key]value[end]) as a tree with keys as
  written, decoded values and line numbers. It knows no table of objects:
  which keys are defined, their types and their meaning is left to the
  mapping. Values are decoded from the character set of the file
  (GAEBInfo/Zeichensatz) and &#nn; escapes are resolved; RTF stays text.

  DE: Formatgetreuer Parser fuer GAEB-DA-2000-Dateien: Objekte und
  Elemente als Baum mit Schluesseln wie geschrieben, dekodierten Werten
  und Zeilennummern. Er kennt keine Objekttabelle: welche Schluessel
  definiert sind, ihre Typen und ihre Bedeutung bleiben der Abbildung
  ueberlassen. Werte werden aus dem Zeichensatz der Datei dekodiert,
  &#nn; aufgeloest; RTF bleibt Text.

  Reading rules:
  - line ends CR LF, LF, CR and CR CR LF; keywords case-insensitive;
  - #begin/#end/## only at the start of a line after white space; ## in a
    value spanning lines is text;
  - [end] at the end of the last line of a value, or alone on a line of
    its own; continuation lines lose white space up to the text column
    (the column after the key), never other characters;
  - an element with an empty value counts as missing;
  - an #end that closes outer objects closes them, an #end without its
    object is ignored (both reported); a file that ends inside an object
    or a value is rejected with ELandrixGaebError and the line.

  Diagnostics (rule identifiers):
    GAEB-BR-D2000-001 error        #begin[GAEB] is not in line 1
    GAEB-BR-D2000-001 information  text after #end[GAEB] ignored
    GAEB-BR-D2000-002 error        #begin/#end not balanced, lines outside
                                   any element
    GAEB-BR-D2000-004 information  &#...; that is no valid escape, kept as
                                   text
    GAEB-BR-D2000-006 information/warning/error  character set missing,
                                   unknown, UNICODE without byte order mark
    GAEB-BR-D2000-014 information  empty elements
    GAEB-BR-D2000-029 information  continuation lines indented to the
                                   column of the key's bracket
  Messages never carry file content.

  DE: Die Meldungen oben haben dieselben Regelkennungen; die Texte sind
  englisch und enthalten keinen Dateiinhalt. }

{ API: internal. May change in any release, also after 1.0; use the
  stable units instead (see README).
  DE: API: intern. Kann sich in jeder Version aendern, auch nach 1.0;
  stattdessen die stabilen Units verwenden (siehe README). }

unit LandrixGaebDA2000Parser;

{$I LandrixGaeb.inc}

interface

uses
  SysUtils,
  Classes,
  Contnrs,
  LandrixGaebTypes,
  LandrixGaebDiagnostics;

type
  TLandrixGaebStringArray = array of TLandrixGaebString;

  { An object or an element of a GAEB DA 2000 file.
    DE: Ein Objekt oder ein Element einer GAEB-DA-2000-Datei. }
  TLandrixGaebDA2000Node = class(TObject)
  private
    FParent: TLandrixGaebDA2000Node;
    FChildren: TObjectList;
    FRaw: AnsiString;
    function GetItem(Index: Integer): TLandrixGaebDA2000Node;
    procedure Add(ANode: TLandrixGaebDA2000Node);
  public
    { Key as written. DE: Schluessel wie geschrieben. }
    Key: string;
    { True for #begin[Key] ... #end[Key]. DE: True fuer ein Objekt. }
    IsObject: Boolean;
    { Decoded value of an element; lines of a value spanning lines are
      separated by #10. DE: Dekodierter Wert eines Elements; Zeilen eines
      mehrzeiligen Werts durch #10 getrennt. }
    Value: TLandrixGaebString;
    { Text after the closing bracket of #begin[Key] (level marker).
      DE: Text hinter der schliessenden Klammer von #begin[Key]. }
    Suffix: string;
    { Line of #begin[Key] or [Key] (1-based). DE: Zeile (ab 1). }
    Line: Integer;
    constructor Create(AParent: TLandrixGaebDA2000Node; const AKey: string;
      AIsObject: Boolean; ALine: Integer);
    destructor Destroy; override;
    function Count: Integer;
    property Items[Index: Integer]: TLandrixGaebDA2000Node read GetItem; default;
    property Parent: TLandrixGaebDA2000Node read FParent;
    { First child with this key (ASCII case-insensitive), nil if none.
      DE: Erstes Kind mit diesem Schluessel, nil wenn keins. }
    function Find(const AKey: string): TLandrixGaebDA2000Node;
    { Value of the first child element with this key, '' if none.
      DE: Wert des ersten Kindelements mit diesem Schluessel. }
    function ValueOf(const AKey: string): TLandrixGaebString;
  end;

  { A parsed GAEB DA 2000 file. DE: Eine gelesene GAEB-DA-2000-Datei. }
  TLandrixGaebDA2000Document = class(TObject)
  private
    FRoot: TLandrixGaebDA2000Node;
  public
    { Character set used for decoding: gcsUnicode means UTF-8.
      DE: Zum Dekodieren benutzter Zeichensatz; gcsUnicode heisst UTF-8. }
    Charset: TLandrixGaebCharset;
    { Text after #end[GAEB] on its line (counters m|n).
      DE: Text hinter #end[GAEB] in seiner Zeile (Zaehler m|n). }
    EndCounters: string;
    destructor Destroy; override;
    { The object GAEB. DE: Das Objekt GAEB. }
    property Root: TLandrixGaebDA2000Node read FRoot;
  end;

{ Parses a GAEB DA 2000 file held in Buffer. ACharset gcsUnknown takes the
  character set from GAEBInfo/Zeichensatz (missing: ANSI); another value
  overrides it. Raises ELandrixGaebError for input that cannot be read
  (no #begin[GAEB], file ending inside an object or value, nesting deeper
  than 64). ADiagnostics may be nil.
  DE: Liest eine GAEB-DA-2000-Datei aus Buffer. ACharset gcsUnknown nimmt
  den Zeichensatz aus GAEBInfo/Zeichensatz (fehlt er: ANSI), ein anderer
  Wert ueberschreibt ihn. Loest ELandrixGaebError fuer Eingaben aus, die
  nicht lesbar sind. ADiagnostics darf nil sein. }
function LandrixGaebDA2000Parse(Buffer: Pointer; Size: Integer;
  ACharset: TLandrixGaebCharset;
  ADiagnostics: TLandrixGaebDiagnostics): TLandrixGaebDA2000Document;

{ The same for a stream from its current position to its end.
  DE: Dasselbe fuer einen Stream ab der aktuellen Position bis zum Ende. }
function LandrixGaebDA2000ParseStream(AStream: TStream;
  ACharset: TLandrixGaebCharset;
  ADiagnostics: TLandrixGaebDiagnostics): TLandrixGaebDA2000Document;

{ Components of a structure value: split at |, where \| is a | inside a
  component. DE: Komponenten eines Strukturwerts: an | getrennt, \| ist
  ein | innerhalb einer Komponente. }
function LandrixGaebDA2000SplitStructure(const AValue: TLandrixGaebString): TLandrixGaebStringArray;

{ Code point of byte AByte in Windows-1252 (AOem False) or code page 850
  (AOem True). DE: Codepunkt des Bytes AByte in Windows-1252 bzw. CP850. }
function LandrixGaebDA2000CharOfByte(AByte: Byte; AOem: Boolean): Cardinal;

implementation

uses
  LandrixXmlBase;

const
  MaxDepth = 64;
  LineFeed: AnsiChar = #10;

  RuleFirstLine = 'GAEB-BR-D2000-001';
  RuleBalance = 'GAEB-BR-D2000-002';
  RuleEscape = 'GAEB-BR-D2000-004';
  RuleCharset = 'GAEB-BR-D2000-006';
  RuleEmpty = 'GAEB-BR-D2000-014';
  RuleIndent = 'GAEB-BR-D2000-029';

  { Windows-1252, bytes $80-$9F; $A0-$FF are U+00A0-U+00FF. Undefined
    bytes keep their value (as LandrixXml does). }
  Cp1252High: array[$80..$9F] of Word = (
    $20AC, $0081, $201A, $0192, $201E, $2026, $2020, $2021,
    $02C6, $2030, $0160, $2039, $0152, $008D, $017D, $008F,
    $0090, $2018, $2019, $201C, $201D, $2022, $2013, $2014,
    $02DC, $2122, $0161, $203A, $0153, $009D, $017E, $0178);

  { Code page 850 (DOS Latin-1, "OEM" of German systems), bytes $80-$FF. }
  Cp850High: array[$80..$FF] of Word = (
    $00C7, $00FC, $00E9, $00E2, $00E4, $00E0, $00E5, $00E7,
    $00EA, $00EB, $00E8, $00EF, $00EE, $00EC, $00C4, $00C5,
    $00C9, $00E6, $00C6, $00F4, $00F6, $00F2, $00FB, $00F9,
    $00FF, $00D6, $00DC, $00F8, $00A3, $00D8, $00D7, $0192,
    $00E1, $00ED, $00F3, $00FA, $00F1, $00D1, $00AA, $00BA,
    $00BF, $00AE, $00AC, $00BD, $00BC, $00A1, $00AB, $00BB,
    $2591, $2592, $2593, $2502, $2524, $00C1, $00C2, $00C0,
    $00A9, $2563, $2551, $2557, $255D, $00A2, $00A5, $2510,
    $2514, $2534, $252C, $251C, $2500, $253C, $00E3, $00C3,
    $255A, $2554, $2569, $2566, $2560, $2550, $256C, $00A4,
    $00F0, $00D0, $00CA, $00CB, $00C8, $0131, $00CD, $00CE,
    $00CF, $2518, $250C, $2588, $2584, $00A6, $00CC, $2580,
    $00D3, $00DF, $00D4, $00D2, $00F5, $00D5, $00B5, $00FE,
    $00DE, $00DA, $00DB, $00D9, $00FD, $00DD, $00AF, $00B4,
    $00AD, $00B1, $2017, $00BE, $00B6, $00A7, $00F7, $00B8,
    $00B0, $00A8, $00B7, $00B9, $00B3, $00B2, $25A0, $00A0);

function LandrixGaebDA2000CharOfByte(AByte: Byte; AOem: Boolean): Cardinal;
begin
  if AByte < $80 then
    Result := AByte
  else if AOem then
    Result := Cp850High[AByte]
  else if AByte <= $9F then
    Result := Cp1252High[AByte]
  else
    Result := AByte;
end;

{ ---- node ---- }

constructor TLandrixGaebDA2000Node.Create(AParent: TLandrixGaebDA2000Node;
  const AKey: string; AIsObject: Boolean; ALine: Integer);
begin
  inherited Create;
  FParent := AParent;
  Key := AKey;
  IsObject := AIsObject;
  Line := ALine;
end;

destructor TLandrixGaebDA2000Node.Destroy;
begin
  FChildren.Free;
  inherited Destroy;
end;

procedure TLandrixGaebDA2000Node.Add(ANode: TLandrixGaebDA2000Node);
begin
  if FChildren = nil then
    FChildren := TObjectList.Create(True);
  FChildren.Add(ANode);
end;

function TLandrixGaebDA2000Node.Count: Integer;
begin
  if FChildren = nil then
    Result := 0
  else
    Result := Integer(FChildren.Count);
end;

function TLandrixGaebDA2000Node.GetItem(Index: Integer): TLandrixGaebDA2000Node;
begin
  Result := TLandrixGaebDA2000Node(FChildren[Index]);
end;

function TLandrixGaebDA2000Node.Find(const AKey: string): TLandrixGaebDA2000Node;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    if CompareText(Items[I].Key, AKey) = 0 then
    begin
      Result := Items[I];
      Exit;
    end;
  Result := nil;
end;

function TLandrixGaebDA2000Node.ValueOf(const AKey: string): TLandrixGaebString;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    if (not Items[I].IsObject) and (CompareText(Items[I].Key, AKey) = 0) then
    begin
      Result := Items[I].Value;
      Exit;
    end;
  Result := '';
end;

destructor TLandrixGaebDA2000Document.Destroy;
begin
  FRoot.Free;
  inherited Destroy;
end;

{ ---- helpers ---- }

function LowerAscii(C: AnsiChar): Integer;
begin
  Result := Ord(C);
  if (C >= 'A') and (C <= 'Z') then
    Inc(Result, 32);
end;

{ True if P[0..Len-1] equals S ignoring ASCII case; S is lower case. }
function SameTextAt(P: PAnsiChar; Len: Integer; const S: string): Boolean;
var
  I: Integer;
begin
  Result := Len = Length(S);
  if not Result then
    Exit;
  for I := 1 to Len do
    if LowerAscii(P[I - 1]) <> Ord(S[I]) then
    begin
      Result := False;
      Exit;
    end;
end;

function BytesToStr(P: PAnsiChar; Len: Integer): string;
var
  I: Integer;
begin
  Result := '';
  SetLength(Result, Len);
  for I := 1 to Len do
    Result[I] := Char(P[I - 1]);
end;

function IsBlank(const S: AnsiString): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to Length(S) do
    if not (S[I] in [' ', #9, #10, #13]) then
      Exit;
  Result := True;
end;

{ ---- parser ---- }

type
  TParser = class(TObject)
  private
    FDiags: TLandrixGaebDiagnostics;
    FDoc: TLandrixGaebDA2000Document;
    FCurrent: TLandrixGaebDA2000Node;
    FDepth: Integer;
    FDone: Boolean;
    FLineNo: Integer;
    FLineStart, FQ: PAnsiChar;
    { value spanning lines }
    FInValue: Boolean;
    FValueKey: string;
    FValueLine, FKeyCol, FTextCol: Integer;
    FValue: AnsiString;
    FValueLen: Integer;
    { counters reported once per file }
    FEmpty, FStray, FStrayLine, FIndentAtKey, FIndentLine: Integer;
    FTrailReported: Boolean;
    FBadEscapes: Integer;
    FUtf8: Boolean;
    FCharset: TLandrixGaebCharset;
    procedure Report(const ARuleId: string; ASeverity: TLandrixGaebSeverity;
      ALine: Integer; const AMessage: string);
    procedure Fail(ALine: Integer; const AMessage: string);
    procedure AppendValue(P: PAnsiChar; Len: Integer);
    procedure FinishElement(const AKey: string; ALine: Integer; const ARaw: AnsiString);
    procedure Line(LineEnd: PAnsiChar);
    procedure ValueLine(LineEnd: PAnsiChar);
    procedure BeginObject(Len: Integer);
    procedure EndObject(Len: Integer);
    procedure Element(LineEnd: PAnsiChar; Len: Integer);
    procedure ChooseCharset(ACharset: TLandrixGaebCharset; P: PAnsiChar; Size: Integer;
      AHasBom: Boolean);
    function Decode(const ARaw: AnsiString): TLandrixGaebString;
    procedure DecodeTree(ANode: TLandrixGaebDA2000Node);
  public
    function Parse(Buffer: Pointer; Size: Integer; ACharset: TLandrixGaebCharset;
      ADiagnostics: TLandrixGaebDiagnostics): TLandrixGaebDA2000Document;
  end;

procedure TParser.Report(const ARuleId: string; ASeverity: TLandrixGaebSeverity;
  ALine: Integer; const AMessage: string);
begin
  if FDiags <> nil then
    FDiags.AddAt(ARuleId, ASeverity, '', ALine, 0, -1, AMessage);
end;

procedure TParser.Fail(ALine: Integer; const AMessage: string);
begin
  raise ELandrixGaebError.Create('GAEB DA 2000, line ' + IntToStr(ALine) + ': ' + AMessage);
end;

procedure TParser.AppendValue(P: PAnsiChar; Len: Integer);
var
  NewCap: Integer;
begin
  if Len <= 0 then
    Exit;
  if FValueLen + Len > Length(FValue) then
  begin
    NewCap := Length(FValue) * 2;
    if NewCap < FValueLen + Len then
      NewCap := FValueLen + Len + 256;
    SetLength(FValue, NewCap);
  end;
  Move(P^, FValue[FValueLen + 1], Len);
  Inc(FValueLen, Len);
end;

procedure TParser.FinishElement(const AKey: string; ALine: Integer; const ARaw: AnsiString);
var
  Node: TLandrixGaebDA2000Node;
begin
  { an empty element counts as missing }
  if IsBlank(ARaw) then
  begin
    Inc(FEmpty);
    Exit;
  end;
  Node := TLandrixGaebDA2000Node.Create(FCurrent, AKey, False, ALine);
  Node.FRaw := ARaw;
  FCurrent.Add(Node);
end;

{ Position of '[end]' that ends the text P[0..Len-1] (only trailing white
  space after it), -1 if none. }
function EndMarkAtEnd(P: PAnsiChar; Len: Integer): Integer;
begin
  while (Len > 0) and (P[Len - 1] in [' ', #9]) do
    Dec(Len);
  if (Len >= 5) and SameTextAt(P + Len - 5, 5, '[end]') then
    Result := Len - 5
  else
    Result := -1;
end;

procedure TParser.ValueLine(LineEnd: PAnsiChar);
var
  P: PAnsiChar;
  W, Len, Mark: Integer;
  Raw: AnsiString;
begin
  { white space up to the text column is indentation, never text }
  P := FLineStart;
  W := 0;
  while (P < LineEnd) and (P^ in [' ', #9]) and (W < FTextCol) do
  begin
    Inc(P);
    Inc(W);
  end;
  Len := Integer(LineEnd - P);
  Mark := EndMarkAtEnd(P, Len);
  if (FKeyCol > 0) and (W = FKeyCol) and (Len > 0) then
  begin
    if FIndentAtKey = 0 then
      FIndentLine := FLineNo;
    Inc(FIndentAtKey);
  end;
  if Mark >= 0 then
  begin
    { [end] alone on its line ends the value without a line of its own }
    if Mark > 0 then
    begin
      AppendValue(@LineFeed, 1);
      AppendValue(P, Mark);
    end;
    SetString(Raw, PAnsiChar(FValue), FValueLen);
    FInValue := False;
    FValue := '';
    FValueLen := 0;
    FinishElement(FValueKey, FValueLine, Raw);
    Exit;
  end;
  AppendValue(@LineFeed, 1);
  AppendValue(P, Len);
end;

procedure TParser.BeginObject(Len: Integer);
var
  Close: Integer;
  Name: string;
  Node: TLandrixGaebDA2000Node;
begin
  Close := 7;
  while (Close < Len) and (FQ[Close] <> ']') do
    Inc(Close);
  if Close >= Len then
  begin
    Report(RuleBalance, gsError, FLineNo, '#begin without closing bracket ignored');
    Exit;
  end;
  Name := BytesToStr(FQ + 7, Close - 7);
  if FCurrent = nil then
  begin
    if (FDoc.FRoot <> nil) or (CompareText(Name, 'GAEB') <> 0) then
    begin
      Report(RuleBalance, gsError, FLineNo, 'object outside the object GAEB ignored');
      Exit;
    end;
    if FLineNo <> 1 then
      Report(RuleFirstLine, gsError, FLineNo, '#begin[GAEB] is not in line 1');
    FDoc.FRoot := TLandrixGaebDA2000Node.Create(nil, Name, True, FLineNo);
    FCurrent := FDoc.FRoot;
    FDepth := 1;
    Exit;
  end;
  if FDepth >= MaxDepth then
    Fail(FLineNo, 'objects nested deeper than ' + IntToStr(MaxDepth));
  Node := TLandrixGaebDA2000Node.Create(FCurrent, Name, True, FLineNo);
  Node.Suffix := Trim(BytesToStr(FQ + Close + 1, Len - Close - 1));
  FCurrent.Add(Node);
  FCurrent := Node;
  Inc(FDepth);
end;

procedure TParser.EndObject(Len: Integer);
var
  Close: Integer;
  Name: string;
  Node: TLandrixGaebDA2000Node;
  Levels: Integer;
begin
  Close := 5;
  while (Close < Len) and (FQ[Close] <> ']') do
    Inc(Close);
  if (Close >= Len) or (FCurrent = nil) then
  begin
    Report(RuleBalance, gsError, FLineNo, '#end without its object ignored');
    Exit;
  end;
  Name := BytesToStr(FQ + 5, Close - 5);
  Node := FCurrent;
  Levels := 1;
  while (Node <> nil) and (CompareText(Node.Key, Name) <> 0) do
  begin
    Node := Node.Parent;
    Inc(Levels);
  end;
  if Node = nil then
  begin
    Report(RuleBalance, gsError, FLineNo, '#end without its object ignored');
    Exit;
  end;
  if Levels > 1 then
    Report(RuleBalance, gsError, FLineNo, IntToStr(Levels - 1) +
      ' object(s) not closed before this #end; closed here');
  if Node = FDoc.FRoot then
  begin
    FDone := True;
    FDoc.EndCounters := Trim(BytesToStr(FQ + Close + 1, Len - Close - 1));
  end;
  FCurrent := Node.Parent;
  Dec(FDepth, Levels);
end;

procedure TParser.Element(LineEnd: PAnsiChar; Len: Integer);
var
  Close, Mark: Integer;
  Key: string;
  Raw: AnsiString;
  Rest: PAnsiChar;
begin
  Close := 1;
  while (Close < Len) and (FQ[Close] <> ']') do
    Inc(Close);
  if (Close >= Len) or (FCurrent = nil) then
  begin
    if FStray = 0 then
      FStrayLine := FLineNo;
    Inc(FStray);
    Exit;
  end;
  Key := BytesToStr(FQ + 1, Close - 1);
  Rest := FQ + Close + 1;
  Mark := EndMarkAtEnd(Rest, Integer(LineEnd - Rest));
  if Mark >= 0 then
  begin
    SetString(Raw, Rest, Mark);
    FinishElement(Key, FLineNo, Raw);
    Exit;
  end;
  FInValue := True;
  FValueKey := Key;
  FValueLine := FLineNo;
  FKeyCol := Integer(FQ - FLineStart);
  FTextCol := FKeyCol + Close + 1;
  FValue := '';
  FValueLen := 0;
  AppendValue(Rest, Integer(LineEnd - Rest));
end;

procedure TParser.Line(LineEnd: PAnsiChar);
var
  Len: Integer;
begin
  if FInValue then
  begin
    ValueLine(LineEnd);
    Exit;
  end;
  FQ := FLineStart;
  while (FQ < LineEnd) and (FQ^ in [' ', #9]) do
    Inc(FQ);
  Len := Integer(LineEnd - FQ);
  if Len = 0 then
    Exit;
  if FDone then
  begin
    if not FTrailReported then
      Report(RuleFirstLine, gsInformation, FLineNo, 'text after #end[GAEB] ignored');
    FTrailReported := True;
    Exit;
  end;
  if (Len >= 2) and (FQ[0] = '#') and (FQ[1] = '#') then
    Exit;
  if (Len >= 7) and SameTextAt(FQ, 7, '#begin[') then
    BeginObject(Len)
  else if (Len >= 5) and SameTextAt(FQ, 5, '#end[') then
    EndObject(Len)
  else if FQ[0] = '[' then
    Element(LineEnd, Len)
  else
  begin
    if FStray = 0 then
      FStrayLine := FLineNo;
    Inc(FStray);
  end;
end;

procedure TParser.ChooseCharset(ACharset: TLandrixGaebCharset; P: PAnsiChar;
  Size: Integer; AHasBom: Boolean);
var
  Info: TLandrixGaebDA2000Node;
  I, Bad: Integer;
  Declared: string;
  Found: Boolean;
begin
  FCharset := ACharset;
  if FCharset = gcsUnknown then
  begin
    FCharset := gcsAnsi;
    Found := False;
    Declared := '';
    Info := FDoc.FRoot.Find('GAEBInfo');
    if Info <> nil then
      for I := 0 to Info.Count - 1 do
        if (not Info[I].IsObject) and (CompareText(Info[I].Key, 'Zeichensatz') = 0) then
        begin
          Found := True;
          Declared := UpperCase(Trim(BytesToStr(PAnsiChar(Info[I].FRaw), Length(Info[I].FRaw))));
          Break;
        end;
    if not Found then
      Report(RuleCharset, gsInformation, 0, 'GAEBInfo/Zeichensatz missing; read as ANSI (Windows-1252)')
    else if Declared = 'ANSI' then
      FCharset := gcsAnsi
    else if Declared = 'OEM' then
      FCharset := gcsOem
    else if Declared = 'UNICODE' then
      FCharset := gcsUnicode
    else
      Report(RuleCharset, gsWarning, 0, 'GAEBInfo/Zeichensatz not known; read as ANSI (Windows-1252)');
  end;
  if AHasBom then
  begin
    if FCharset <> gcsUnicode then
      Report(RuleCharset, gsWarning, 0, 'UTF-8 byte order mark; read as UTF-8, not as the declared character set');
    FCharset := gcsUnicode;
  end
  else if FCharset = gcsUnicode then
  begin
    { UNICODE does not name an encoding: UTF-8 when the bytes are UTF-8 }
    if LandrixXmlValidateUtf8Buf(P, Size, Bad) then
      Report(RuleCharset, gsWarning, 0, 'Zeichensatz UNICODE without byte order mark; read as UTF-8')
    else
    begin
      Report(RuleCharset, gsError, 0,
        'Zeichensatz UNICODE, but the bytes are not UTF-8; read as ANSI (Windows-1252)');
      FCharset := gcsAnsi;
    end;
  end;
  FUtf8 := FCharset = gcsUnicode;
  FDoc.Charset := FCharset;
end;

function TParser.Decode(const ARaw: AnsiString): TLandrixGaebString;
var
  P: PAnsiChar;
  I, Len, N, J, Count: Integer;
  CP: Cardinal;
  B: Byte;
  Valid: Boolean;

  procedure Put(ACode: Cardinal);
  begin
    if ACode > $FFFF then
    begin
      Dec(ACode, $10000);
      Inc(Count);
      Result[Count] := WideChar($D800 + (ACode shr 10));
      Inc(Count);
      Result[Count] := WideChar($DC00 + (ACode and $3FF));
    end
    else
    begin
      Inc(Count);
      Result[Count] := WideChar(ACode);
    end;
  end;

  function SingleByte(AByte: Cardinal): Cardinal;
  begin
    Result := LandrixGaebDA2000CharOfByte(Byte(AByte), FCharset = gcsOem);
  end;

begin
  Len := Length(ARaw);
  Result := '';
  SetLength(Result, Len);
  if Len = 0 then
    Exit;
  P := PAnsiChar(ARaw);
  Count := 0;
  I := 0;
  while I < Len do
  begin
    B := Ord(P[I]);
    if (B = Ord('&')) and (I + 1 < Len) and (P[I + 1] = '#') then
    begin
      { &#nn; is the character nn of the file's character set }
      J := I + 2;
      CP := 0;
      while (J < Len) and (J - I - 2 < 7) and (P[J] >= '0') and (P[J] <= '9') do
      begin
        CP := CP * 10 + Cardinal(Ord(P[J]) - Ord('0'));
        Inc(J);
      end;
      Valid := (J > I + 2) and (J < Len) and (P[J] = ';');
      if Valid then
        if FUtf8 then
          Valid := (CP > 0) and (CP <= $10FFFF) and ((CP < $D800) or (CP > $DFFF))
        else
          Valid := (CP > 0) and (CP <= 255);
      if Valid then
      begin
        if FUtf8 then
          Put(CP)
        else
          Put(SingleByte(CP));
        I := J + 1;
        Continue;
      end;
      Inc(FBadEscapes);
    end;
    if (B >= $80) and FUtf8 then
    begin
      N := LandrixXmlDecodeUtf8(P + I, Len - I, CP);
      if N <= 0 then
      begin
        CP := $FFFD;
        N := 1;
      end;
      Put(CP);
      Inc(I, N);
      Continue;
    end;
    Put(SingleByte(B));
    Inc(I);
  end;
  SetLength(Result, Count);
end;

procedure TParser.DecodeTree(ANode: TLandrixGaebDA2000Node);
var
  I: Integer;
begin
  for I := 0 to ANode.Count - 1 do
    if ANode[I].IsObject then
      DecodeTree(ANode[I])
    else
    begin
      ANode[I].Value := Decode(ANode[I].FRaw);
      ANode[I].FRaw := '';
    end;
end;

function TParser.Parse(Buffer: Pointer; Size: Integer; ACharset: TLandrixGaebCharset;
  ADiagnostics: TLandrixGaebDiagnostics): TLandrixGaebDA2000Document;
var
  P, Stop, LineEnd, Start: PAnsiChar;
  HasBom: Boolean;
  Open: TLandrixGaebDA2000Node;
begin
  FDiags := ADiagnostics;
  P := PAnsiChar(Buffer);
  Stop := P + Size;
  HasBom := (Size >= 3) and (P[0] = #$EF) and (P[1] = #$BB) and (P[2] = #$BF);
  if HasBom then
    Inc(P, 3);
  Start := P;
  FDoc := TLandrixGaebDA2000Document.Create;
  try
    while P < Stop do
    begin
      FLineStart := P;
      while (P < Stop) and not (P^ in [#10, #13]) do
        Inc(P);
      LineEnd := P;
      { CR LF, LF, CR and CR CR LF end one line }
      if (P < Stop) and (P^ = #13) then
      begin
        Inc(P);
        if (P + 1 < Stop) and (P^ = #13) and (P[1] = #10) then
          Inc(P, 2)
        else if (P < Stop) and (P^ = #10) then
          Inc(P);
      end
      else if (P < Stop) and (P^ = #10) then
        Inc(P);
      Inc(FLineNo);
      Line(LineEnd);
    end;
    if FInValue then
      Fail(FValueLine, 'value of an element without [end] runs to the end of the file');
    if FDoc.FRoot = nil then
      Fail(1, '#begin[GAEB] missing');
    if not FDone then
    begin
      Open := FCurrent;
      Fail(Open.Line, 'object not closed: the file ends inside it (truncated?)');
    end;
    if FStray > 0 then
      Report(RuleBalance, gsError, FStrayLine, IntToStr(FStray) + ' line(s) outside any element ignored');
    if FEmpty > 0 then
      Report(RuleEmpty, gsInformation, 0, IntToStr(FEmpty) + ' empty element(s) treated as missing');
    if FIndentAtKey > 0 then
      Report(RuleIndent, gsInformation, FIndentLine, IntToStr(FIndentAtKey) +
        ' continuation line(s) indented to the column of the key''s bracket');
    ChooseCharset(ACharset, Start, Integer(Stop - Start), HasBom);
    DecodeTree(FDoc.FRoot);
    if FBadEscapes > 0 then
      Report(RuleEscape, gsInformation, 0, IntToStr(FBadEscapes) +
        ' &#...; sequence(s) that are no valid escape kept as text');
  except
    FDoc.Free;
    raise;
  end;
  Result := FDoc;
end;

function LandrixGaebDA2000Parse(Buffer: Pointer; Size: Integer;
  ACharset: TLandrixGaebCharset;
  ADiagnostics: TLandrixGaebDiagnostics): TLandrixGaebDA2000Document;
var
  Parser: TParser;
begin
  Parser := TParser.Create;
  try
    Result := Parser.Parse(Buffer, Size, ACharset, ADiagnostics);
  finally
    Parser.Free;
  end;
end;

function LandrixGaebDA2000ParseStream(AStream: TStream;
  ACharset: TLandrixGaebCharset;
  ADiagnostics: TLandrixGaebDiagnostics): TLandrixGaebDA2000Document;
var
  Buffer: AnsiString;
  Remaining: Int64;
  Count: Integer;
begin
  Remaining := AStream.Size - AStream.Position;
  if Remaining > MaxInt then
    raise ELandrixGaebError.Create('GAEB DA 2000: input of ' + IntToStr(Remaining) +
      ' bytes is too large');
  Count := Integer(Remaining);
  Buffer := '';
  SetLength(Buffer, Count);
  if Count > 0 then
    AStream.ReadBuffer(Buffer[1], Count);
  Result := LandrixGaebDA2000Parse(Pointer(Buffer), Count, ACharset, ADiagnostics);
end;

function LandrixGaebDA2000SplitStructure(const AValue: TLandrixGaebString): TLandrixGaebStringArray;
var
  I, J, K, N, Len: Integer;
  Part: TLandrixGaebString;
begin
  { linear: each component is sized once and filled character by
    character (no repeated concatenation of WideString) }
  Result := nil;
  N := 0;
  Len := Length(AValue);
  I := 1;
  repeat
    J := I;
    while (J <= Len) and (AValue[J] <> '|') do
      if (AValue[J] = '\') and (J < Len) and (AValue[J + 1] = '|') then
        Inc(J, 2)
      else
        Inc(J);
    Part := '';
    SetLength(Part, J - I);
    K := 0;
    while I < J do
    begin
      if (AValue[I] = '\') and (I + 1 < J) and (AValue[I + 1] = '|') then
        Inc(I);
      Inc(K);
      Part[K] := AValue[I];
      Inc(I);
    end;
    SetLength(Part, K);
    if N >= Length(Result) then
      SetLength(Result, 2 * N + 4);
    Result[N] := Part;
    Inc(N);
    { skip the separator; a trailing one leaves an empty last component }
    Inc(I);
  until I > Len + 1;
  SetLength(Result, N);
end;

end.
