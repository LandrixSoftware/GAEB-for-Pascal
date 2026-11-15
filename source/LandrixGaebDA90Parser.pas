{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Record reader for GAEB 90 files: the file is decoded as a whole and cut
  into records of 80 columns with their record numbers and physical lines.
  It knows no table of record types: which records are defined, their
  fields and their meaning is left to the mapping.

  DE: Satzleser fuer GAEB-90-Dateien: die Datei wird als Ganzes dekodiert
  und in Saetze von 80 Spalten mit Satznummer und physischer Zeile
  zerlegt. Er kennt keine Satzartentabelle: welche Saetze definiert sind,
  ihre Felder und ihre Bedeutung bleiben der Abbildung ueberlassen.

  Character set (GAEB 90 does not define one): the caller may give it;
  otherwise a byte order mark or valid UTF-8 with multi-byte sequences
  means UTF-8, else the umlauts of the whole file decide between ANSI
  (Windows-1252) and OEM (code page 850, or 437 when asked for): umlaut
  bytes of a code page next to a letter count for it, the OEM bytes of
  ae and oe (typographic quotes in ANSI) only between two letters, and
  runs of OEM box drawing characters count for OEM. A file without
  umlauts is read as ANSI. Columns count characters (code points), so a
  UTF-8 file has 80 characters per record, not 80 bytes.

  File physics (not regulated by GAEB 90), tolerated and reported once per
  kind with a count:
  - line ends LF, CR LF, CR and CR CR LF; records chained without a line
    end by NUL NUL in columns 81 and 82; Ctrl-Z at the end; blank lines;
    a UTF-8 byte order mark;
  - records shorter than 80 characters are read padded with spaces,
    columns after 80 are ignored;
  - NUL and Ctrl-Z inside a record are read as spaces.

  Diagnostics (rule identifiers):
    GAEB-D90-FILE-001 information  character set and how it was chosen
    GAEB-D90-FILE-002 warning      umlauts of both ANSI and OEM (mixed file)
    GAEB-D90-FILE-003 information  line ends, chained records, Ctrl-Z at
                                   the end, blank lines, byte order mark
    GAEB-D90-FILE-004 information/warning  records shorter / longer than
                                   80 characters
    GAEB-D90-FILE-005 warning      NUL or Ctrl-Z inside records, bytes that
                                   are no valid UTF-8 (read as
                                   Windows-1252)
    GAEB-BR-D90-002   warning      record numbers missing, not consecutive
                                   from 000001, or the number of record 99
                                   other than its position
  Messages never carry file content.

  DE: Die Meldungen oben haben dieselben Regelkennungen; die Texte sind
  englisch und enthalten keinen Dateiinhalt. }

{ API: internal. May change in any release, also after 1.0; use the
  stable units instead (see README).
  DE: API: intern. Kann sich in jeder Version aendern, auch nach 1.0;
  stattdessen die stabilen Units verwenden (siehe README). }

unit LandrixGaebDA90Parser;

{$I LandrixGaeb.inc}

interface

uses
  SysUtils,
  Classes,
  LandrixGaebTypes,
  LandrixGaebDiagnostics,
  LandrixGaebCharsets;

const
  { Columns of a GAEB 90 record. DE: Spalten eines GAEB-90-Satzes. }
  LandrixGaebDA90RecordLength = 80;

type
  { The records of a GAEB 90 file, in file order. All records share one
    decoded string; a record is its start and length in it. A column is a
    character (a code point: a surrogate pair is one column).
    DE: Die Saetze einer GAEB-90-Datei in Dateireihenfolge. Alle Saetze
    teilen einen dekodierten String; ein Satz ist Anfang und Laenge darin.
    Eine Spalte ist ein Zeichen (ein Codepunkt: ein Surrogatpaar ist eine
    Spalte). }
  TLandrixGaebDA90Document = class(TObject)
  private
    FText: TLandrixGaebString;
    FStart: array of Integer;
    FLen: array of Integer;
    FCols: array of Integer;
    FLine: array of Integer;
    FNumber: array of Integer;
    FCount: Integer;
    function NextUnit(AUnit, AStop: Integer): Integer;
    function ColumnUnit(AStart, AStop, AColumn: Integer): Integer;
    procedure Add(AStart, ALen, ALine: Integer);
  public
    { Character set used for decoding: gcsAnsi, gcsOem or gcsUnicode
      (UTF-8). DE: Zum Dekodieren benutzter Zeichensatz: gcsAnsi, gcsOem
      oder gcsUnicode (UTF-8). }
    Charset: TLandrixGaebCharset;
    { Code page of gcsAnsi (Windows-1252) and gcsOem (850 or 437).
      DE: Codepage von gcsAnsi (Windows-1252) und gcsOem (850 oder 437). }
    CodePage: TLandrixGaebCodePage;
    { Number of records. DE: Anzahl der Saetze. }
    property Count: Integer read FCount;
    { Record type, columns 1 and 2; characters outside ASCII as '?'.
      DE: Satzart, Spalten 1 und 2; Zeichen ausserhalb ASCII als '?'. }
    function Kind(AIndex: Integer): string;
    { Columns AFrom to ATo (1-based, at most 80) of record AIndex, padded
      with spaces where the record is shorter.
      DE: Spalten AFrom bis ATo (ab 1, hoechstens 80) des Satzes AIndex,
      mit Leerzeichen aufgefuellt, wo der Satz kuerzer ist. }
    function Field(AIndex, AFrom, ATo: Integer): TLandrixGaebString;
    { Physical line of the record (1-based); chained records share it.
      DE: Physische Zeile des Satzes (ab 1); verkettete Saetze teilen sie. }
    function Line(AIndex: Integer): Integer;
    { Record number (columns 75-80), -1 if they are not six digits.
      DE: Satznummer (Spalten 75-80), -1 wenn keine sechs Ziffern. }
    function Number(AIndex: Integer): Integer;
    { Columns (characters) of the record as read, before padding or
      cutting. DE: Spalten (Zeichen) des Satzes wie gelesen, vor
      Auffuellen oder Kuerzen. }
    function RecordLength(AIndex: Integer): Integer;
  end;

{ Reads the records of a GAEB 90 file held in Buffer. ACharset gcsUnknown
  decides the character set from the bytes (see above); gcsAnsi, gcsOem or
  gcsUnicode (UTF-8) override it. AOemCodePage is the code page of OEM
  (gcpCp850 or gcpCp437). Raises ELandrixGaebError when the input holds no
  record or is larger than MaxInt div 2 bytes. ADiagnostics may be nil.
  DE: Liest die Saetze einer GAEB-90-Datei aus Buffer. ACharset gcsUnknown
  bestimmt den Zeichensatz aus den Bytes (siehe oben); gcsAnsi, gcsOem
  oder gcsUnicode (UTF-8) ueberschreiben ihn. AOemCodePage ist die
  Codepage von OEM (gcpCp850 oder gcpCp437). Loest ELandrixGaebError aus,
  wenn die Eingabe keinen Satz enthaelt oder groesser als MaxInt div 2
  Bytes ist. ADiagnostics darf nil sein. }
function LandrixGaebDA90Parse(Buffer: Pointer; Size: Integer;
  ACharset: TLandrixGaebCharset; AOemCodePage: TLandrixGaebCodePage;
  ADiagnostics: TLandrixGaebDiagnostics): TLandrixGaebDA90Document;

{ The same for a stream from its current position to its end.
  DE: Dasselbe fuer einen Stream ab der aktuellen Position bis zum Ende. }
function LandrixGaebDA90ParseStream(AStream: TStream;
  ACharset: TLandrixGaebCharset; AOemCodePage: TLandrixGaebCodePage;
  ADiagnostics: TLandrixGaebDiagnostics): TLandrixGaebDA90Document;

implementation

uses
  LandrixXmlBase;

const
  RuleCharset = 'GAEB-D90-FILE-001';
  RuleMixed = 'GAEB-D90-FILE-002';
  RulePhysics = 'GAEB-D90-FILE-003';
  RuleLength = 'GAEB-D90-FILE-004';
  RuleControl = 'GAEB-D90-FILE-005';
  RuleNumbers = 'GAEB-BR-D90-002';
  { largest input the reader takes (bytes) }
  MaxInputSize = MaxInt div 2;

{ ---- document ---- }

{ The unit after the character at AUnit (a surrogate pair is one). }
function TLandrixGaebDA90Document.NextUnit(AUnit, AStop: Integer): Integer;
begin
  if (Ord(FText[AUnit]) >= $D800) and (Ord(FText[AUnit]) <= $DBFF) and (AUnit + 1 < AStop) and
    (Ord(FText[AUnit + 1]) >= $DC00) and (Ord(FText[AUnit + 1]) <= $DFFF) then
    Result := AUnit + 2
  else
    Result := AUnit + 1;
end;

{ The unit where column AColumn (1-based) starts in the units AStart to
  AStop - 1; AStop when the text is shorter. }
function TLandrixGaebDA90Document.ColumnUnit(AStart, AStop, AColumn: Integer): Integer;
var
  Col: Integer;
begin
  Result := AStart;
  Col := 1;
  while (Col < AColumn) and (Result < AStop) do
  begin
    Result := NextUnit(Result, AStop);
    Inc(Col);
  end;
end;

procedure TLandrixGaebDA90Document.Add(AStart, ALen, ALine: Integer);
var
  I, N, Cols, Stop: Integer;
  Digits: TLandrixGaebString;
begin
  if FCount >= Length(FStart) then
  begin
    SetLength(FStart, 2 * FCount + 64);
    SetLength(FLen, 2 * FCount + 64);
    SetLength(FCols, 2 * FCount + 64);
    SetLength(FLine, 2 * FCount + 64);
    SetLength(FNumber, 2 * FCount + 64);
  end;
  FStart[FCount] := AStart;
  FLen[FCount] := ALen;
  FLine[FCount] := ALine;
  Cols := 0;
  I := AStart;
  Stop := AStart + ALen;
  while I < Stop do
  begin
    I := NextUnit(I, Stop);
    Inc(Cols);
  end;
  FCols[FCount] := Cols;
  Inc(FCount);
  N := -1;
  if Cols >= LandrixGaebDA90RecordLength then
  begin
    Digits := Field(FCount - 1, 75, 80);
    N := 0;
    for I := 1 to Length(Digits) do
      if (Digits[I] < '0') or (Digits[I] > '9') or (Length(Digits) <> 6) then
      begin
        N := -1;
        Break;
      end
      else
        N := N * 10 + (Ord(Digits[I]) - Ord('0'));
  end;
  FNumber[FCount - 1] := N;
end;

function TLandrixGaebDA90Document.Kind(AIndex: Integer): string;
var
  F: TLandrixGaebString;
  I: Integer;
begin
  Result := '  ';
  for I := 1 to 2 do
  begin
    { one column each: a surrogate pair is one character }
    F := Field(AIndex, I, I);
    if (Length(F) = 1) and (Ord(F[1]) < 128) then
      Result[I] := Char(Ord(F[1]))
    else
      Result[I] := '?';
  end;
end;

function TLandrixGaebDA90Document.Field(AIndex, AFrom, ATo: Integer): TLandrixGaebString;
var
  K, Stop, Next, Col, N: Integer;
begin
  Result := '';
  if AFrom < 1 then
    AFrom := 1;
  if ATo > LandrixGaebDA90RecordLength then
    ATo := LandrixGaebDA90RecordLength;
  if ATo < AFrom then
    Exit;
  { at most two units per column }
  SetLength(Result, 2 * (ATo - AFrom + 1));
  N := 0;
  Stop := FStart[AIndex] + FLen[AIndex];
  K := ColumnUnit(FStart[AIndex], Stop, AFrom);
  for Col := AFrom to ATo do
    if K < Stop then
    begin
      Next := NextUnit(K, Stop);
      while K < Next do
      begin
        Inc(N);
        Result[N] := FText[K];
        Inc(K);
      end;
    end
    else
    begin
      Inc(N);
      Result[N] := ' ';
    end;
  SetLength(Result, N);
end;

function TLandrixGaebDA90Document.Line(AIndex: Integer): Integer;
begin
  Result := FLine[AIndex];
end;

function TLandrixGaebDA90Document.Number(AIndex: Integer): Integer;
begin
  Result := FNumber[AIndex];
end;

function TLandrixGaebDA90Document.RecordLength(AIndex: Integer): Integer;
begin
  Result := FCols[AIndex];
end;

{ ---- character set ---- }

function IsAsciiLetter(B: Byte): Boolean;
begin
  Result := ((B >= Ord('A')) and (B <= Ord('Z'))) or ((B >= Ord('a')) and (B <= Ord('z')));
end;

{ Umlauts (ae oe ue Ae Oe Ue ss) in code page 850/437 and in Windows-1252. }
function IsOemUmlaut(B: Byte): Boolean;
begin
  Result := (B = $81) or (B = $84) or (B = $8E) or (B = $94) or (B = $99) or (B = $9A) or (B = $E1);
end;

function IsAnsiUmlaut(B: Byte): Boolean;
begin
  Result := (B = $C4) or (B = $D6) or (B = $DC) or (B = $DF) or (B = $E4) or (B = $F6) or (B = $FC);
end;

function IsAnsiLowerUmlaut(B: Byte): Boolean;
begin
  Result := (B = $E4) or (B = $F6) or (B = $FC);
end;

{ N divided by 10, rounded up, without overflow. }
function TenthUp(N: Integer): Integer;
begin
  Result := N div 10;
  if N mod 10 <> 0 then
    Inc(Result);
end;

{ True if byte B is a box drawing or block character in code page
  ACodePage (U+2500 to U+259F). }
function IsBoxByte(B: Byte; ACodePage: TLandrixGaebCodePage): Boolean;
var
  C: Cardinal;
begin
  C := LandrixGaebCodePointOfByte(B, ACodePage);
  Result := (C >= $2500) and (C <= $259F);
end;

{ Umlaut bytes of each code page next to an ASCII letter (for OEM also
  next to another OEM umlaut, for ANSI next to a lower-case ANSI ae, oe or
  ue: the ANSI bytes of upper-case umlauts and sharp s are box drawing
  characters in OEM); the OEM bytes of ae and oe, which are typographic
  quotes in Windows-1252, only between two such characters, so an OEM ae
  or oe at the start of a word does not count. A run of three or more
  equal box drawing bytes of the OEM code page counts once for OEM, and
  its bytes count for nothing else. }
procedure ScoreUmlauts(P: PAnsiChar; Size: Integer; AOemCodePage: TLandrixGaebCodePage;
  out AOem, AAnsi: Integer);
var
  I, J: Integer;
  B, Prev, Next: Byte;
  LP, LN: Boolean;
begin
  AOem := 0;
  AAnsi := 0;
  I := 0;
  while I < Size do
  begin
    B := Byte(P[I]);
    if B < $80 then
    begin
      Inc(I);
      Continue;
    end;
    if IsBoxByte(B, AOemCodePage) then
    begin
      J := I + 1;
      while (J < Size) and (Byte(P[J]) = B) do
        Inc(J);
      if J - I >= 3 then
      begin
        Inc(AOem);
        I := J;
        Continue;
      end;
    end;
    if I > 0 then
      Prev := Byte(P[I - 1])
    else
      Prev := Ord(' ');
    if I + 1 < Size then
      Next := Byte(P[I + 1])
    else
      Next := Ord(' ');
    if IsOemUmlaut(B) then
    begin
      LP := IsAsciiLetter(Prev) or IsOemUmlaut(Prev);
      LN := IsAsciiLetter(Next) or IsOemUmlaut(Next);
      if (LP and LN) or ((B <> $84) and (B <> $94) and (LP or LN)) then
        Inc(AOem);
    end;
    if IsAnsiUmlaut(B) then
    begin
      LP := IsAsciiLetter(Prev) or IsAnsiLowerUmlaut(Prev);
      LN := IsAsciiLetter(Next) or IsAnsiLowerUmlaut(Next);
      if LP or LN then
        Inc(AAnsi);
    end;
    Inc(I);
  end;
end;

function HasHighBytes(P: PAnsiChar; Size: Integer): Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := 0 to Size - 1 do
    if Byte(P[I]) >= $80 then
      Exit;
  Result := False;
end;

function CharsetName(ACharset: TLandrixGaebCharset; ACodePage: TLandrixGaebCodePage): string;
begin
  if ACharset = gcsUnicode then
    Result := 'UTF-8'
  else if ACodePage = gcpCp850 then
    Result := 'OEM (code page 850)'
  else if ACodePage = gcpCp437 then
    Result := 'OEM (code page 437)'
  else
    Result := 'ANSI (Windows-1252)';
end;

{ ---- reading ---- }

type
  TReader = class(TObject)
  private
    FDiags: TLandrixGaebDiagnostics;
    FDoc: TLandrixGaebDA90Document;
    FInvalidUtf8: Integer;
    procedure Report(const ARuleId: string; ASeverity: TLandrixGaebSeverity;
      ALine: Integer; const AMessage: string);
    procedure Decode(P: PAnsiChar; Size: Integer);
    procedure Split;
  public
    constructor Create(ADiags: TLandrixGaebDiagnostics);
    function Run(Buffer: Pointer; Size: Integer; ACharset: TLandrixGaebCharset;
      AOemCodePage: TLandrixGaebCodePage): TLandrixGaebDA90Document;
  end;

constructor TReader.Create(ADiags: TLandrixGaebDiagnostics);
begin
  inherited Create;
  FDiags := ADiags;
end;

procedure TReader.Report(const ARuleId: string; ASeverity: TLandrixGaebSeverity;
  ALine: Integer; const AMessage: string);
begin
  if FDiags <> nil then
    FDiags.AddAt(ARuleId, ASeverity, '', ALine, 0, -1, AMessage);
end;

{ Decodes the whole input into FDoc.FText (UTF-16; a code point above
  U+FFFF takes two units). }
procedure TReader.Decode(P: PAnsiChar; Size: Integer);
var
  I, N, Count: Integer;
  CP: Cardinal;

  procedure Put(ACode: Cardinal);
  begin
    if ACode > $FFFF then
    begin
      Dec(ACode, $10000);
      Inc(Count);
      FDoc.FText[Count] := TLandrixGaebChar($D800 + (ACode shr 10));
      Inc(Count);
      FDoc.FText[Count] := TLandrixGaebChar($DC00 + (ACode and $3FF));
    end
    else
    begin
      Inc(Count);
      FDoc.FText[Count] := TLandrixGaebChar(ACode);
    end;
  end;

begin
  FDoc.FText := '';
  { a UTF-8 sequence never yields more units than bytes }
  SetLength(FDoc.FText, Size);
  Count := 0;
  I := 0;
  while I < Size do
  begin
    if FDoc.Charset = gcsUnicode then
    begin
      if Byte(P[I]) < $80 then
      begin
        Put(Byte(P[I]));
        Inc(I);
        Continue;
      end;
      N := LandrixXmlDecodeUtf8(P + I, Size - I, CP);
      if N > 0 then
      begin
        Put(CP);
        Inc(I, N);
        Continue;
      end;
      { not UTF-8 (only when the caller asked for UTF-8): the byte as
        Windows-1252 }
      Inc(FInvalidUtf8);
      Put(LandrixGaebCodePointOfByte(Byte(P[I]), gcpWindows1252));
      Inc(I);
    end
    else
    begin
      Put(LandrixGaebCodePointOfByte(Byte(P[I]), FDoc.CodePage));
      Inc(I);
    end;
  end;
  SetLength(FDoc.FText, Count);
end;

{ Cuts FDoc.FText into records. }
procedure TReader.Split;
var
  T: TLandrixGaebString;
  Len, I, J, S, E, LineNo, CrRun: Integer;
  Glued, CrCrLf, Blank, Control, Short, Long, Gaps, NoNumber: Integer;
  FirstGlued, FirstControl, FirstShort, FirstLong, FirstGap, FirstNoNumber: Integer;
  CtrlZEnd: Boolean;
  Expect, Ordinal: Integer;

  { One record from AStart (ALen characters): NUL and Ctrl-Z become spaces,
    a record of spaces only is a blank line. }
  procedure TakeRecord(AStart, ALen: Integer);
  var
    K: Integer;
    AllSpace: Boolean;
  begin
    AllSpace := True;
    for K := AStart to AStart + ALen - 1 do
    begin
      if (T[K] = #0) or (T[K] = #26) then
      begin
        if Control = 0 then
          FirstControl := LineNo;
        Inc(Control);
        T[K] := ' ';
      end;
      if T[K] <> ' ' then
        AllSpace := False;
    end;
    if AllSpace then
      Inc(Blank)
    else
      FDoc.Add(AStart, ALen, LineNo);
  end;

  procedure TakeLine(AStart, AEnd: Integer);
  var
    Col81: Integer;
    Chained: Boolean;
  begin
    { records of 80 characters chained by NUL NUL (columns 81 and 82)
      instead of a line end }
    Chained := False;
    repeat
      Col81 := FDoc.ColumnUnit(AStart, AEnd, LandrixGaebDA90RecordLength + 1);
      if (Col81 + 1 < AEnd) and (T[Col81] = #0) and (T[Col81 + 1] = #0) then
      begin
        if Glued = 0 then
          FirstGlued := LineNo;
        Inc(Glued);
        TakeRecord(AStart, Col81 - AStart);
        AStart := Col81 + 2;
        Chained := True;
      end
      else
        Break;
    until False;
    { a chain that ends with its NUL NUL leaves no record behind }
    if not (Chained and (AStart >= AEnd)) then
      TakeRecord(AStart, AEnd - AStart);
  end;

begin
  T := FDoc.FText;
  Len := Length(T);
  { Ctrl-Z at the end, possibly followed by line ends and spaces }
  CtrlZEnd := False;
  E := Len;
  while (E > 0) and ((T[E] = #10) or (T[E] = #13) or (T[E] = ' ') or (T[E] = #26)) do
  begin
    if T[E] = #26 then
    begin
      CtrlZEnd := True;
      Len := E - 1;
    end;
    Dec(E);
  end;
  Glued := 0;
  CrCrLf := 0;
  Blank := 0;
  Control := 0;
  FirstGlued := 0;
  FirstControl := 0;
  LineNo := 1;
  S := 1;
  I := 1;
  while I <= Len do
  begin
    if T[I] = #10 then
    begin
      TakeLine(S, I);
      Inc(LineNo);
      Inc(I);
      S := I;
    end
    else if T[I] = #13 then
    begin
      J := I;
      CrRun := 0;
      while (J <= Len) and (T[J] = #13) do
      begin
        Inc(CrRun);
        Inc(J);
      end;
      if (J <= Len) and (T[J] = #10) then
      begin
        { CR CR LF is one line end; further CRs before it end empty lines }
        if CrRun >= 2 then
        begin
          Inc(CrCrLf);
          Dec(CrRun);
        end;
        Inc(J);
      end;
      TakeLine(S, I);
      { lone CRs beyond the first end empty lines }
      Inc(LineNo, CrRun);
      Inc(Blank, CrRun - 1);
      I := J;
      S := I;
    end
    else
      Inc(I);
  end;
  if S <= Len then
    TakeLine(S, Len + 1);
  FDoc.FText := T;
  if FDoc.FCount = 0 then
    raise ELandrixGaebError.Create('GAEB 90: no record found');

  if CrCrLf > 0 then
    Report(RulePhysics, gsInformation, 0, IntToStr(CrCrLf) + ' line end(s) CR CR LF');
  if Glued > 0 then
    Report(RulePhysics, gsInformation, FirstGlued, IntToStr(Glued) +
      ' record(s) chained by NUL NUL instead of a line end');
  if CtrlZEnd then
    Report(RulePhysics, gsInformation, 0, 'Ctrl-Z at the end of the file ignored');
  if Blank > 0 then
    Report(RulePhysics, gsInformation, 0, IntToStr(Blank) + ' blank line(s) ignored');
  if Control > 0 then
    Report(RuleControl, gsWarning, FirstControl, IntToStr(Control) +
      ' NUL or Ctrl-Z character(s) inside records read as spaces');

  Short := 0;
  Long := 0;
  Gaps := 0;
  NoNumber := 0;
  FirstShort := 0;
  FirstLong := 0;
  FirstGap := 0;
  FirstNoNumber := 0;
  Expect := 1;
  for Ordinal := 0 to FDoc.FCount - 1 do
  begin
    if FDoc.FCols[Ordinal] < LandrixGaebDA90RecordLength then
    begin
      if Short = 0 then
        FirstShort := FDoc.FLine[Ordinal];
      Inc(Short);
    end
    else if FDoc.FCols[Ordinal] > LandrixGaebDA90RecordLength then
    begin
      if Long = 0 then
        FirstLong := FDoc.FLine[Ordinal];
      Inc(Long);
    end;
    if FDoc.FNumber[Ordinal] < 0 then
    begin
      if NoNumber = 0 then
        FirstNoNumber := FDoc.FLine[Ordinal];
      Inc(NoNumber);
    end
    else
    begin
      if FDoc.FNumber[Ordinal] <> Expect then
      begin
        if Gaps = 0 then
          FirstGap := FDoc.FLine[Ordinal];
        Inc(Gaps);
      end;
      Expect := FDoc.FNumber[Ordinal] + 1;
      if (FDoc.Kind(Ordinal) = '99') and (FDoc.FNumber[Ordinal] <> Ordinal + 1) then
        Report(RuleNumbers, gsWarning, FDoc.FLine[Ordinal],
          'the record number of record 99 differs from its position in the file');
    end;
  end;
  if Short > 0 then
    Report(RuleLength, gsInformation, FirstShort, IntToStr(Short) +
      ' record(s) shorter than 80 characters, read padded with spaces');
  if Long > 0 then
    Report(RuleLength, gsWarning, FirstLong, IntToStr(Long) +
      ' record(s) longer than 80 characters, columns after 80 ignored');
  if NoNumber > 0 then
    Report(RuleNumbers, gsWarning, FirstNoNumber, IntToStr(NoNumber) +
      ' record(s) without a six-digit record number');
  if Gaps > 0 then
    Report(RuleNumbers, gsWarning, FirstGap, IntToStr(Gaps) +
      ' break(s) in the record numbers (not consecutive from 000001)');
end;

function TReader.Run(Buffer: Pointer; Size: Integer; ACharset: TLandrixGaebCharset;
  AOemCodePage: TLandrixGaebCodePage): TLandrixGaebDA90Document;
var
  P: PAnsiChar;
  Oem, Ansi, Bad: Integer;
  How: string;
begin
  P := PAnsiChar(Buffer);
  How := '';
  if Size < 0 then
    Size := 0;
  { the decoded text takes two bytes per character, and indexes run to
    Size + 1: larger input cannot be held }
  if Size > MaxInputSize then
    raise ELandrixGaebError.Create('GAEB 90: input of ' + IntToStr(Size) + ' bytes is too large');
  FDoc := TLandrixGaebDA90Document.Create;
  try
    if AOemCodePage = gcpWindows1252 then
      AOemCodePage := gcpCp850;
    { UTF-8 byte order mark }
    if (Size >= 3) and (P[0] = #$EF) and (P[1] = #$BB) and (P[2] = #$BF) then
    begin
      Report(RulePhysics, gsInformation, 1, 'UTF-8 byte order mark');
      Inc(P, 3);
      Dec(Size, 3);
      if ACharset = gcsUnknown then
      begin
        ACharset := gcsUnicode;
        How := 'from the byte order mark';
      end;
    end;
    if ACharset <> gcsUnknown then
    begin
      FDoc.Charset := ACharset;
      if How = '' then
        How := 'as given by the caller';
    end
    else if HasHighBytes(P, Size) and LandrixXmlValidateUtf8Buf(P, Size, Bad) then
    begin
      FDoc.Charset := gcsUnicode;
      How := 'from the bytes (valid UTF-8)';
    end
    else
    begin
      ScoreUmlauts(P, Size, AOemCodePage, Oem, Ansi);
      if Oem > Ansi then
        FDoc.Charset := gcsOem
      else
        FDoc.Charset := gcsAnsi;
      if (Oem = 0) and (Ansi = 0) then
        How := 'without umlauts'
      else
        How := 'from the umlauts';
      { the smaller count is at least a tenth of the larger one }
      if (Oem > 0) and (Ansi > 0) and (Oem >= TenthUp(Ansi)) and (Ansi >= TenthUp(Oem)) then
        Report(RuleMixed, gsWarning, 0, 'umlauts of both ANSI (' + IntToStr(Ansi) + ') and OEM (' +
          IntToStr(Oem) + '); the file is read as one character set');
    end;
    if FDoc.Charset = gcsOem then
      FDoc.CodePage := AOemCodePage
    else
      FDoc.CodePage := gcpWindows1252;
    Report(RuleCharset, gsInformation, 0, 'character set ' + CharsetName(FDoc.Charset, FDoc.CodePage) +
      ', ' + How);
    Decode(P, Size);
    if FInvalidUtf8 > 0 then
      Report(RuleControl, gsWarning, 0, IntToStr(FInvalidUtf8) +
        ' byte(s) that are no valid UTF-8 read as Windows-1252');
    Split;
    Result := FDoc;
  except
    FDoc.Free;
    raise;
  end;
end;

function LandrixGaebDA90Parse(Buffer: Pointer; Size: Integer;
  ACharset: TLandrixGaebCharset; AOemCodePage: TLandrixGaebCodePage;
  ADiagnostics: TLandrixGaebDiagnostics): TLandrixGaebDA90Document;
var
  R: TReader;
begin
  R := TReader.Create(ADiagnostics);
  try
    Result := R.Run(Buffer, Size, ACharset, AOemCodePage);
  finally
    R.Free;
  end;
end;

function LandrixGaebDA90ParseStream(AStream: TStream;
  ACharset: TLandrixGaebCharset; AOemCodePage: TLandrixGaebCodePage;
  ADiagnostics: TLandrixGaebDiagnostics): TLandrixGaebDA90Document;
var
  Buffer: AnsiString;
  Remaining: Int64;
  Count: Integer;
begin
  Remaining := AStream.Size - AStream.Position;
  if Remaining > MaxInputSize then
    raise ELandrixGaebError.Create('GAEB 90: input of ' + IntToStr(Remaining) +
      ' bytes is too large');
  Count := Integer(Remaining);
  Buffer := '';
  SetLength(Buffer, Count);
  if Count > 0 then
    AStream.ReadBuffer(Buffer[1], Count);
  Result := LandrixGaebDA90Parse(Pointer(Buffer), Count, ACharset, AOemCodePage, ADiagnostics);
end;

end.
