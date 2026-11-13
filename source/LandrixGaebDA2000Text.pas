{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Texts of GAEB DA 2000 (Langtext, Kurztext and others): RTF or plain
  text, read as paragraphs of plain text with text complements.

  RTF becomes plain text: \par, \sect, \page and \row end a paragraph;
  \line is a line break (#10) inside the paragraph; \tab and \cell are a
  tab; \~ is a no-break space; \'xx (code page from \ansicpg, else 1252)
  and \uN are characters. Fonts, colours, character formats, pictures,
  objects, shapes and all destinations marked with \* are dropped.
  Losses reports what changes the reading of a text: emphasis (bold,
  italic, underline, strike-through, sub- and superscript), tables,
  pictures and objects; fonts, sizes and colours are dropped silently.

  Text complements are two bookmarks: the outer one TAnn (owner) or TBnn
  (bidder) around caption, field and tail, the inner one Feldnn around the
  field. They become a part with Caption, Body and Tail; a field that is
  empty or holds only dots, underscores and white space is Empty. Marks
  that do not pair (nested, missing end, field outside a mark) keep their
  text as plain text and count in MarkProblems. Other bookmarks are
  ignored.

  A value that does not start with the RTF group (\rtf) is plain
  text: each line is a paragraph.

  DE: Texte von GAEB DA 2000 (RTF oder Klartext) als Absaetze aus Klartext
  mit Textergaenzungen. RTF wird Klartext; Schriften, Farben, Zeichen-
  formate, Bilder, Objekte und mit \* markierte Ziele fallen weg (Losses).
  Textergaenzungen (aeussere Marke TAnn/TBnn, innere Feldnn) werden ein
  Teil mit Caption, Body und Tail; ein leeres oder nur aus Punkten,
  Unterstrichen und Leerraum bestehendes Feld ist Empty. Unpaarige Marken
  behalten ihren Text als Klartext und zaehlen in MarkProblems. Ein Wert,
  der nicht mit der RTF-Gruppe (\rtf) beginnt, ist Klartext: jede
  Zeile ein Absatz. }

{ API: internal. May change in any release, also after 1.0; use the
  stable units instead (see README).
  DE: API: intern. Kann sich in jeder Version aendern, auch nach 1.0;
  stattdessen die stabilen Units verwenden (siehe README). }

unit LandrixGaebDA2000Text;

{$I LandrixGaeb.inc}

interface

uses
  SysUtils,
  Classes,
  Contnrs,
  LandrixGaebTypes;

type
  { Kind of a part of a paragraph. DE: Art eines Absatzteils. }
  TLandrixGaebDA2000PartKind = (tpkText, tpkComplement);

  { What the conversion to plain text dropped. DE: Was die Umwandlung in
    Klartext verworfen hat. }
  TLandrixGaebDA2000Loss = (tlCharFormat, tlTable, tlPicture, tlObject);
  TLandrixGaebDA2000Losses = set of TLandrixGaebDA2000Loss;

  { Plain text, or a text complement. DE: Klartext oder Textergaenzung. }
  TLandrixGaebDA2000TextPart = class(TObject)
  public
    Kind: TLandrixGaebDA2000PartKind;
    { tpkText: the text. DE: tpkText: der Text. }
    Text: TLandrixGaebString;
    { tpkComplement: TBnn (True) or TAnn (False). DE: TBnn (True) oder
      TAnn (False). }
    Bidder: Boolean;
    { tpkComplement: nn of the mark. DE: nn der Marke. }
    Number: Integer;
    { tpkComplement: text before, in and after the field.
      DE: Text vor, in und nach dem Feld. }
    Caption, Body, Tail: TLandrixGaebString;
    { tpkComplement: the field is empty or a placeholder; Body is ''.
      DE: Das Feld ist leer oder ein Platzhalter; Body ist ''. }
    Empty: Boolean;
  end;

  { A paragraph: parts in order. DE: Ein Absatz: Teile in Reihenfolge. }
  TLandrixGaebDA2000Paragraph = class(TObject)
  private
    FParts: TObjectList;
    function GetItem(Index: Integer): TLandrixGaebDA2000TextPart;
  public
    constructor Create;
    destructor Destroy; override;
    function Count: Integer;
    function Add: TLandrixGaebDA2000TextPart;
    property Items[Index: Integer]: TLandrixGaebDA2000TextPart read GetItem; default;
  end;

  { A text read from a value. DE: Ein aus einem Wert gelesener Text. }
  TLandrixGaebDA2000Text = class(TObject)
  private
    FParagraphs: TObjectList;
    function GetItem(Index: Integer): TLandrixGaebDA2000Paragraph;
  public
    { True if the value was RTF. DE: True, wenn der Wert RTF war. }
    IsRtf: Boolean;
    { Formatting that was dropped. DE: Verworfene Formatierung. }
    Losses: TLandrixGaebDA2000Losses;
    { Bookmarks of complements that did not pair. DE: Unpaarige Marken. }
    MarkProblems: Integer;
    constructor Create;
    destructor Destroy; override;
    function Count: Integer;
    function Add: TLandrixGaebDA2000Paragraph;
    property Items[Index: Integer]: TLandrixGaebDA2000Paragraph read GetItem; default;
    { Number of complements. DE: Anzahl der Textergaenzungen. }
    function ComplementCount: Integer;
    { Paragraphs joined by #10, a complement as caption, body and tail.
      DE: Absaetze durch #10 verbunden, eine Ergaenzung als Caption, Body
      und Tail. }
    function PlainText: TLandrixGaebString;
  end;

{ Reads a decoded value of GAEB DA 2000 as text. Never raises for any
  input. DE: Liest einen dekodierten Wert als Text; loest fuer keine
  Eingabe eine Ausnahme aus. }
function LandrixGaebDA2000ReadText(const AValue: TLandrixGaebString): TLandrixGaebDA2000Text;

implementation

uses
  LandrixGaebDA2000Parser;

{ ---- text buffer (no WideString concatenation per character) ---- }

type
  TTextBuffer = class(TObject)
  private
    FData: TLandrixGaebString;
    FLen: Integer;
  public
    procedure Add(C: WideChar);
    procedure AddCode(ACode: Cardinal);
    procedure AddText(const S: TLandrixGaebString);
    procedure Clear;
    function Text: TLandrixGaebString;
    property Len: Integer read FLen;
  end;

procedure TTextBuffer.Add(C: WideChar);
begin
  if FLen >= Length(FData) then
    SetLength(FData, 2 * FLen + 64);
  Inc(FLen);
  FData[FLen] := C;
end;

procedure TTextBuffer.AddCode(ACode: Cardinal);
begin
  if ACode > $FFFF then
  begin
    Dec(ACode, $10000);
    Add(WideChar($D800 + (ACode shr 10)));
    Add(WideChar($DC00 + (ACode and $3FF)));
  end
  else
    Add(WideChar(ACode));
end;

procedure TTextBuffer.AddText(const S: TLandrixGaebString);
var
  I: Integer;
begin
  for I := 1 to Length(S) do
    Add(S[I]);
end;

procedure TTextBuffer.Clear;
begin
  FLen := 0;
end;

function TTextBuffer.Text: TLandrixGaebString;
begin
  Result := Copy(FData, 1, FLen);
end;

{ ---- containers ---- }

constructor TLandrixGaebDA2000Paragraph.Create;
begin
  inherited Create;
  FParts := TObjectList.Create(True);
end;

destructor TLandrixGaebDA2000Paragraph.Destroy;
begin
  FParts.Free;
  inherited Destroy;
end;

function TLandrixGaebDA2000Paragraph.Count: Integer;
begin
  Result := Integer(FParts.Count);
end;

function TLandrixGaebDA2000Paragraph.Add: TLandrixGaebDA2000TextPart;
begin
  Result := TLandrixGaebDA2000TextPart.Create;
  FParts.Add(Result);
end;

function TLandrixGaebDA2000Paragraph.GetItem(Index: Integer): TLandrixGaebDA2000TextPart;
begin
  Result := TLandrixGaebDA2000TextPart(FParts[Index]);
end;

constructor TLandrixGaebDA2000Text.Create;
begin
  inherited Create;
  FParagraphs := TObjectList.Create(True);
end;

destructor TLandrixGaebDA2000Text.Destroy;
begin
  FParagraphs.Free;
  inherited Destroy;
end;

function TLandrixGaebDA2000Text.Count: Integer;
begin
  Result := Integer(FParagraphs.Count);
end;

function TLandrixGaebDA2000Text.Add: TLandrixGaebDA2000Paragraph;
begin
  Result := TLandrixGaebDA2000Paragraph.Create;
  FParagraphs.Add(Result);
end;

function TLandrixGaebDA2000Text.GetItem(Index: Integer): TLandrixGaebDA2000Paragraph;
begin
  Result := TLandrixGaebDA2000Paragraph(FParagraphs[Index]);
end;

function TLandrixGaebDA2000Text.ComplementCount: Integer;
var
  I, J: Integer;
begin
  Result := 0;
  for I := 0 to Count - 1 do
    for J := 0 to Items[I].Count - 1 do
      if Items[I][J].Kind = tpkComplement then
        Inc(Result);
end;

function TLandrixGaebDA2000Text.PlainText: TLandrixGaebString;
var
  I, J: Integer;
  Part: TLandrixGaebDA2000TextPart;
  Buffer: TTextBuffer;
begin
  Buffer := TTextBuffer.Create;
  try
    for I := 0 to Count - 1 do
    begin
      if I > 0 then
        Buffer.Add(#10);
      for J := 0 to Items[I].Count - 1 do
      begin
        Part := Items[I][J];
        if Part.Kind = tpkText then
          Buffer.AddText(Part.Text)
        else
        begin
          Buffer.AddText(Part.Caption);
          Buffer.AddText(Part.Body);
          Buffer.AddText(Part.Tail);
        end;
      end;
    end;
    Result := Buffer.Text;
  finally
    Buffer.Free;
  end;
end;

{ ---- reader ---- }

function HexValue(C: WideChar): Integer;
begin
  if (C >= '0') and (C <= '9') then
    Result := Ord(C) - Ord('0')
  else if (C >= 'a') and (C <= 'f') then
    Result := Ord(C) - Ord('a') + 10
  else if (C >= 'A') and (C <= 'F') then
    Result := Ord(C) - Ord('A') + 10
  else
    Result := -1;
end;

{ A bookmark name as an ASCII string, trimmed; other characters as '?'. }
function AsciiName(const S: TLandrixGaebString): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(S) do
    if Ord(S[I]) < 128 then
      Result := Result + Char(Ord(S[I]))
    else
      Result := Result + '?';
  Result := Trim(Result);
end;

type
  TGroupState = record
    Skip: Boolean;
    Ignorable: Boolean;
    { 0 none, 1 bookmark start, 2 bookmark end }
    Dest: Integer;
    Uc: Integer;
    FirstWord: Boolean;
  end;

  TRtfReader = class(TObject)
  private
    FText: TLandrixGaebDA2000Text;
    FPara: TLandrixGaebDA2000Paragraph;
    FRun: TTextBuffer;
    { open complement }
    FMarkOpen: Boolean;
    FMarkBidder: Boolean;
    FMarkNumber: Integer;
    FFieldNumber: Integer;
    FStage: Integer;
    { a field mark of the open complement did not pair }
    FBroken: Boolean;
    FCaption, FBody, FTail: TTextBuffer;
    FName: TTextBuffer;
    FStack: array of TGroupState;
    FDepth: Integer;
    FState: TGroupState;
    FUcSkip: Integer;
    FOem: Boolean;
    procedure FlushRun;
    procedure NewParagraph;
    procedure Emit(C: WideChar);
    procedure EmitCode(ACode: Cardinal);
    procedure Bookmark(AStart: Boolean; const AName: string);
    procedure DropMark;
    procedure CloseMark;
    procedure ControlWord(const AWord: string; AHasParam: Boolean; AParam: Integer);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Read(const S: TLandrixGaebString; AText: TLandrixGaebDA2000Text);
  end;

constructor TRtfReader.Create;
begin
  inherited Create;
  FRun := TTextBuffer.Create;
  FCaption := TTextBuffer.Create;
  FBody := TTextBuffer.Create;
  FTail := TTextBuffer.Create;
  FName := TTextBuffer.Create;
end;

destructor TRtfReader.Destroy;
begin
  FRun.Free;
  FCaption.Free;
  FBody.Free;
  FTail.Free;
  FName.Free;
  inherited Destroy;
end;

procedure TRtfReader.FlushRun;
var
  Part: TLandrixGaebDA2000TextPart;
begin
  if FRun.Len = 0 then
    Exit;
  Part := FPara.Add;
  Part.Kind := tpkText;
  Part.Text := FRun.Text;
  FRun.Clear;
end;

procedure TRtfReader.NewParagraph;
begin
  if FMarkOpen then
  begin
    { a paragraph end inside a complement stays a line break there }
    Emit(#10);
    Exit;
  end;
  FlushRun;
  FPara := FText.Add;
end;

procedure TRtfReader.Emit(C: WideChar);
begin
  if FState.Skip then
    Exit;
  if FState.Dest <> 0 then
  begin
    FName.Add(C);
    Exit;
  end;
  if not FMarkOpen then
    FRun.Add(C)
  else if FStage = 0 then
    FCaption.Add(C)
  else if FStage = 1 then
    FBody.Add(C)
  else
    FTail.Add(C);
end;

procedure TRtfReader.EmitCode(ACode: Cardinal);
begin
  if ACode > $FFFF then
  begin
    Dec(ACode, $10000);
    Emit(WideChar($D800 + (ACode shr 10)));
    Emit(WideChar($DC00 + (ACode and $3FF)));
  end
  else
    Emit(WideChar(ACode));
end;

{ The text of an open mark becomes plain text. }
procedure TRtfReader.DropMark;
begin
  if not FMarkOpen then
    Exit;
  FMarkOpen := False;
  FRun.AddText(FCaption.Text);
  FRun.AddText(FBody.Text);
  FRun.AddText(FTail.Text);
  Inc(FText.MarkProblems);
end;

function IsPlaceholder(const S: TLandrixGaebString): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to Length(S) do
    if not ((S[I] = '.') or (S[I] = '_') or (S[I] = ' ') or (S[I] = #9) or
      (S[I] = #10) or (S[I] = #13) or (S[I] = WideChar($A0)) or (S[I] = WideChar($2026))) then
      Exit;
  Result := True;
end;

procedure TRtfReader.CloseMark;
var
  Part: TLandrixGaebDA2000TextPart;
begin
  FlushRun;
  Part := FPara.Add;
  Part.Kind := tpkComplement;
  Part.Bidder := FMarkBidder;
  Part.Number := FMarkNumber;
  Part.Caption := FCaption.Text;
  Part.Body := FBody.Text;
  Part.Tail := FTail.Text;
  Part.Empty := IsPlaceholder(Part.Body);
  if Part.Empty then
    Part.Body := '';
  FMarkOpen := False;
end;

{ Number of a mark name Prefix+digits, -1 if it is no such name. }
function MarkNumber(const AName, APrefix: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  if (Length(AName) <= Length(APrefix)) or (Length(AName) > Length(APrefix) + 6) or
    (CompareText(Copy(AName, 1, Length(APrefix)), APrefix) <> 0) then
    Exit;
  for I := Length(APrefix) + 1 to Length(AName) do
    if (AName[I] < '0') or (AName[I] > '9') then
      Exit;
  Result := StrToInt(Copy(AName, Length(APrefix) + 1, MaxInt));
end;

procedure TRtfReader.Bookmark(AStart: Boolean; const AName: string);
var
  N: Integer;
  Bidder: Boolean;
begin
  Bidder := True;
  N := MarkNumber(AName, 'TB');
  if N < 0 then
  begin
    Bidder := False;
    N := MarkNumber(AName, 'TA');
  end;
  if N >= 0 then
  begin
    if AStart then
    begin
      { complements are not nested }
      DropMark;
      FMarkOpen := True;
      FMarkBidder := Bidder;
      FMarkNumber := N;
      FStage := 0;
      FBroken := False;
      FCaption.Clear;
      FBody.Clear;
      FTail.Clear;
    end
    else if FMarkOpen and (FMarkBidder = Bidder) and (FMarkNumber = N) then
    begin
      if (FStage <> 2) or FBroken then
        { no field, or a field without its end: keep the text, drop the
          complement }
        DropMark
      else
        CloseMark;
    end
    else
      Inc(FText.MarkProblems);
    Exit;
  end;
  N := MarkNumber(AName, 'Feld');
  if N < 0 then
    Exit;
  if AStart then
  begin
    if FMarkOpen and (FStage = 0) then
    begin
      FStage := 1;
      FFieldNumber := N;
    end
    else
    begin
      Inc(FText.MarkProblems);
      FBroken := FMarkOpen;
    end;
  end
  else if FMarkOpen and (FStage = 1) and (FFieldNumber = N) then
    FStage := 2
  else
  begin
    Inc(FText.MarkProblems);
    FBroken := FMarkOpen;
  end;
end;

function IsSkippedDestination(const W: string): Boolean;
begin
  Result := (W = 'fonttbl') or (W = 'colortbl') or (W = 'stylesheet') or (W = 'info') or
    (W = 'pict') or (W = 'object') or (W = 'shp') or (W = 'shpinst') or (W = 'shprslt') or
    (W = 'header') or (W = 'headerl') or (W = 'headerr') or (W = 'headerf') or
    (W = 'footer') or (W = 'footerl') or (W = 'footerr') or (W = 'footerf') or
    (W = 'footnote') or (W = 'listtable') or (W = 'listoverridetable') or
    (W = 'rsidtbl') or (W = 'fldinst') or (W = 'nonshppict') or (W = 'xmlnstbl') or
    (W = 'themedata') or (W = 'colorschememapping') or (W = 'latentstyles') or
    (W = 'datastore') or (W = 'generator') or (W = 'filetbl') or (W = 'revtbl') or
    (W = 'pgdsctbl') or (W = 'bkmkstart') or (W = 'bkmkend');
end;

procedure TRtfReader.ControlWord(const AWord: string; AHasParam: Boolean; AParam: Integer);
var
  First: Boolean;
begin
  First := FState.FirstWord;
  FState.FirstWord := False;
  if First then
  begin
    if (AWord = 'bkmkstart') or (AWord = 'bkmkend') then
    begin
      if not FState.Skip then
      begin
        if AWord = 'bkmkstart' then
          FState.Dest := 1
        else
          FState.Dest := 2;
        FName.Clear;
      end;
      Exit;
    end;
    if FState.Ignorable or IsSkippedDestination(AWord) then
    begin
      FState.Skip := True;
      if AWord = 'pict' then
        Include(FText.Losses, tlPicture)
      else if (AWord = 'object') or (AWord = 'shp') then
        Include(FText.Losses, tlObject);
      Exit;
    end;
  end;
  if FState.Skip then
    Exit;
  if (AWord = 'par') or (AWord = 'sect') or (AWord = 'page') or (AWord = 'row') then
    NewParagraph
  else if AWord = 'line' then
    Emit(#10)
  else if (AWord = 'tab') or (AWord = 'cell') or (AWord = 'nestcell') then
    Emit(#9)
  else if AWord = 'u' then
  begin
    if AParam < 0 then
      Inc(AParam, 65536);
    EmitCode(Cardinal(AParam));
    FUcSkip := FState.Uc;
  end
  else if AWord = 'uc' then
    FState.Uc := AParam
  else if AWord = 'ansicpg' then
    FOem := (AParam = 850) or (AParam = 437)
  else if (AWord = 'pc') or (AWord = 'pca') then
    FOem := True
  else if AWord = 'emdash' then
    EmitCode($2014)
  else if AWord = 'endash' then
    EmitCode($2013)
  else if AWord = 'bullet' then
    EmitCode($2022)
  else if AWord = 'lquote' then
    EmitCode($2018)
  else if AWord = 'rquote' then
    EmitCode($2019)
  else if AWord = 'ldblquote' then
    EmitCode($201C)
  else if AWord = 'rdblquote' then
    EmitCode($201D)
  else if (AWord = 'emspace') or (AWord = 'enspace') or (AWord = 'qmspace') then
    Emit(' ')
  else if AWord = 'trowd' then
    Include(FText.Losses, tlTable)
  else if ((AWord = 'b') or (AWord = 'i') or (AWord = 'strike') or (AWord = 'striked') or
    (AWord = 'sub') or (AWord = 'super') or
    { underline and its variants (uldb, ulwave, ...), not ulnone or the colour ulc }
    ((Copy(AWord, 1, 2) = 'ul') and (AWord <> 'ulnone') and (AWord <> 'ulc'))) and
    ((not AHasParam) or (AParam <> 0)) then
    Include(FText.Losses, tlCharFormat);
end;

procedure TRtfReader.Read(const S: TLandrixGaebString; AText: TLandrixGaebDA2000Text);
var
  I, Len, J, Param: Integer;
  C: WideChar;
  W: string;
  Neg, HasParam: Boolean;
  Code: Integer;
begin
  FText := AText;
  FText.IsRtf := True;
  FPara := FText.Add;
  FState.Skip := False;
  FState.Ignorable := False;
  FState.Dest := 0;
  FState.Uc := 1;
  FState.FirstWord := False;
  FDepth := 0;
  FStack := nil;
  Len := Length(S);
  I := 1;
  while I <= Len do
  begin
    C := S[I];
    if C = '{' then
    begin
      { a pending \uN fallback ends at a group boundary }
      FUcSkip := 0;
      if FDepth >= Length(FStack) then
        SetLength(FStack, 2 * FDepth + 16);
      FStack[FDepth] := FState;
      Inc(FDepth);
      FState.Ignorable := False;
      FState.Dest := 0;
      FState.FirstWord := True;
      Inc(I);
      Continue;
    end;
    if C = '}' then
    begin
      FUcSkip := 0;
      if FState.Dest <> 0 then
        Bookmark(FState.Dest = 1, AsciiName(FName.Text));
      if FDepth > 0 then
      begin
        Dec(FDepth);
        FState := FStack[FDepth];
      end;
      Inc(I);
      Continue;
    end;
    if C = '\' then
    begin
      Inc(I);
      if I > Len then
        Break;
      C := S[I];
      if ((C >= 'a') and (C <= 'z')) or ((C >= 'A') and (C <= 'Z')) then
      begin
        J := I;
        while (I <= Len) and (((S[I] >= 'a') and (S[I] <= 'z')) or ((S[I] >= 'A') and (S[I] <= 'Z'))) do
          Inc(I);
        W := '';
        while J < I do
        begin
          W := W + Char(Ord(S[J]));
          Inc(J);
        end;
        W := LowerCase(W);
        Neg := (I <= Len) and (S[I] = '-');
        if Neg then
          Inc(I);
        { the value counts, not the digits: leading zeros are fine, a value
          beyond 10^8 is clamped }
        Param := 0;
        HasParam := False;
        while (I <= Len) and (S[I] >= '0') and (S[I] <= '9') do
        begin
          if Param < 100000000 then
            Param := Param * 10 + (Ord(S[I]) - Ord('0'));
          HasParam := True;
          Inc(I);
        end;
        if Neg then
          Param := -Param;
        if (I <= Len) and (S[I] = ' ') then
          Inc(I);
        if FUcSkip > 0 then
        begin
          { a control word is one fallback character; \bin with its data too }
          Dec(FUcSkip);
          if (W = 'bin') and (Param > 0) then
            Inc(I, Param);
          Continue;
        end;
        ControlWord(W, HasParam, Param);
        if (W = 'bin') and (Param > 0) then
          { binary data: never text }
          Inc(I, Param);
        Continue;
      end;
      { control symbols; \* keeps the next word the first of its group }
      Inc(I);
      if C = '*' then
      begin
        FState.Ignorable := True;
        Continue;
      end;
      FState.FirstWord := False;
      Code := -1;
      if C = '''' then
        if (I + 1 <= Len) and (HexValue(S[I]) >= 0) and (HexValue(S[I + 1]) >= 0) then
        begin
          Code := HexValue(S[I]) * 16 + HexValue(S[I + 1]);
          Inc(I, 2);
        end;
      if FUcSkip > 0 then
      begin
        { a control symbol is one fallback character }
        Dec(FUcSkip);
        Continue;
      end;
      if C = '''' then
      begin
        if Code >= 0 then
          EmitCode(LandrixGaebDA2000CharOfByte(Byte(Code), FOem));
      end
      else if C = '~' then
        Emit(WideChar($A0))
      else if C = '_' then
        Emit('-')
      else if C = '-' then
        { optional hyphen }
      else if (C = '\') or (C = '{') or (C = '}') then
        Emit(C)
      else if ((C = #10) or (C = #13)) and not FState.Skip then
        NewParagraph;
      Continue;
    end;
    Inc(I);
    if (C = #10) or (C = #13) then
      Continue;
    FState.FirstWord := False;
    if FUcSkip > 0 then
    begin
      Dec(FUcSkip);
      Continue;
    end;
    Emit(C);
  end;
  DropMark;
  FlushRun;
end;

{ Removes empty paragraphs at the end. }
procedure TrimParagraphs(AText: TLandrixGaebDA2000Text);
begin
  while (AText.Count > 0) and (AText[AText.Count - 1].Count = 0) do
    AText.FParagraphs.Delete(AText.Count - 1);
end;

function IsRtfValue(const S: TLandrixGaebString): Boolean;
var
  I: Integer;
begin
  I := 1;
  while (I <= Length(S)) and ((S[I] = ' ') or (S[I] = #9) or (S[I] = #10) or (S[I] = #13)) do
    Inc(I);
  Result := (I + 4 <= Length(S)) and (S[I] = '{') and (S[I + 1] = '\') and
    (S[I + 2] = 'r') and (S[I + 3] = 't') and (S[I + 4] = 'f');
end;

procedure ReadPlain(const S: TLandrixGaebString; AText: TLandrixGaebDA2000Text);
var
  I, Start: Integer;
  Part: TLandrixGaebDA2000TextPart;
  Para: TLandrixGaebDA2000Paragraph;
begin
  { CR LF, CR and LF end a line }
  Start := 1;
  I := 1;
  while I <= Length(S) + 1 do
  begin
    if (I > Length(S)) or (S[I] = #10) or (S[I] = #13) then
    begin
      Para := AText.Add;
      if I > Start then
      begin
        Part := Para.Add;
        Part.Kind := tpkText;
        Part.Text := Copy(S, Start, I - Start);
      end;
      if (I < Length(S)) and (S[I] = #13) and (S[I + 1] = #10) then
        Inc(I);
      Start := I + 1;
    end;
    Inc(I);
  end;
end;

function LandrixGaebDA2000ReadText(const AValue: TLandrixGaebString): TLandrixGaebDA2000Text;
var
  Reader: TRtfReader;
begin
  Result := TLandrixGaebDA2000Text.Create;
  try
    if IsRtfValue(AValue) then
    begin
      Reader := TRtfReader.Create;
      try
        Reader.Read(AValue, Result);
      finally
        Reader.Free;
      end;
    end
    else
      ReadPlain(AValue, Result);
    TrimParagraphs(Result);
  except
    Result.Free;
    raise;
  end;
end;

end.
