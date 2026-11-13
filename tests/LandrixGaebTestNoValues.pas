{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Test helper: diagnostic messages must never contain values of the file
  (legacy review, case 37). Collects the text and attribute values of a
  document - without names and codes of the schema, namespace declarations
  and values shorter than three bytes - and looks for them in the messages
  as whole words.
  A failure names the rule and the length of the value, never the value,
  so the helper can run on real files. }

unit LandrixGaebTestNoValues;

{$I LandrixGaeb.inc}

interface

uses
  LandrixXmlBase,
  LandrixGaebDiagnostics;

type
  TFileValues = array of TLandrixXmlUtf8;

{ Text and attribute values of the document ASource (UTF-8 bytes). }
function FileValues(const ASource: TLandrixXmlUtf8): TFileValues;

{ Number of diagnostics whose message contains a value of AValues; AFirst
  gets rule and value length of the first one. }
function CountValueLeaks(const AValues: TFileValues; ADiags: TLandrixGaebDiagnostics;
  out AFirst: string): Integer;

{ Fails if a message of ADiags contains a value of ASource. }
procedure CheckNoFileValues(const ASource: TLandrixXmlUtf8; ADiags: TLandrixGaebDiagnostics;
  const AContext: string);

{ The file content as UTF-8 bytes. }
function ReadFileBytes(const AFileName: string): TLandrixXmlUtf8;

implementation

uses
  SysUtils,
  Classes,
  LandrixXmlReader,
  LandrixGaebTypes,
  LandrixGaebXmlGrammar,
  LandrixGaebTestFramework;

const
  XmlnsPrefix: TLandrixXmlUtf8 = 'xmlns';

function IsVocabulary(const S: TLandrixXmlUtf8): Boolean;
var
  L, R, M, I: Integer;
begin
  Result := True;
  L := 0;
  R := High(LandrixGaebXmlGrammarNames);
  while L <= R do
  begin
    M := (L + R) div 2;
    if LandrixGaebXmlGrammarNames[M] = S then
      Exit;
    if LandrixGaebXmlGrammarNames[M] < S then
      L := M + 1
    else
      R := M - 1;
  end;
  for I := 0 to High(LandrixGaebXmlGrammarTexts) do
    if LandrixGaebXmlGrammarTexts[I] = S then
      Exit;
  { the versions 3.0 and 3.1 are read but have no grammar; like the version
    enumerations of 3.2 and 3.3 they are vocabulary (and appear in validator
    codes such as cvc-type.3.1.3) }
  Result := (S = LandrixGaebXmlGrammarRootName) or (S = '3.0') or (S = '3.1');
end;

function TrimUtf8(const S: TLandrixXmlUtf8): TLandrixXmlUtf8;
var
  A, B: Integer;
begin
  A := 1;
  B := Integer(Length(S));
  while (A <= B) and (S[A] <= ' ') do
    Inc(A);
  while (B >= A) and (S[B] <= ' ') do
    Dec(B);
  Result := Copy(S, A, B - A + 1);
end;

procedure AddValue(var AValues: TFileValues; var ACount: Integer; const AValue: TLandrixXmlUtf8);
var
  V: TLandrixXmlUtf8;
begin
  V := TrimUtf8(AValue);
  if (Integer(Length(V)) < 3) or IsVocabulary(V) then
    Exit;
  if ACount = Integer(Length(AValues)) then
    SetLength(AValues, 2 * ACount + 16);
  AValues[ACount] := V;
  Inc(ACount);
end;

function FileValues(const ASource: TLandrixXmlUtf8): TFileValues;
var
  Reader: TLandrixXmlReader;
  I, Count: Integer;
  Text: TLandrixXmlUtf8;
begin
  Result := nil;
  Count := 0;
  Text := '';
  Reader := TLandrixXmlReader.Create;
  try
    { decoded values (entities, CDATA); input that is not well-formed
      gives the values read up to the error (none for invalid UTF-8,
      which the reader rejects on loading) }
    try
      Reader.LoadFromUtf8(ASource);
      { adjacent text and CDATA pieces form one value }
      while Reader.Read do
        case Reader.TokenType of
          xttText, xttCData:
            Text := Text + Reader.ValueUtf8;
        else
          AddValue(Result, Count, Text);
          Text := '';
          if Reader.TokenType = xttStartElement then
            for I := 0 to Reader.AttributeCount - 1 do
              if Copy(Reader.AttributeNameUtf8(I), 1, 5) <> XmlnsPrefix then
                AddValue(Result, Count, Reader.AttributeValueUtf8(I));
        end;
      AddValue(Result, Count, Text);
    except
      on ELandrixXmlError do
        ;
    end;
  finally
    Reader.Free;
  end;
  SetLength(Result, Count);
end;

function IsWordByte(C: AnsiChar): Boolean;
begin
  Result := ((C >= '0') and (C <= '9')) or ((C >= 'A') and (C <= 'Z')) or
    ((C >= 'a') and (C <= 'z')) or (C >= #$80);
end;

{ True if AValue occurs in AText as a whole word (no letter or digit
  directly before or after it), so that "und" does not match
  "underscores". }
function ContainsWord(const AText, AValue: TLandrixXmlUtf8): Boolean;
var
  I, L: Integer;
begin
  Result := False;
  L := Integer(Length(AValue));
  for I := 1 to Integer(Length(AText)) - L + 1 do
    if (AText[I] = AValue[1]) and (Copy(AText, I, L) = AValue) and
      ((I = 1) or not IsWordByte(AnsiChar(AText[I - 1]))) and
      ((I + L > Integer(Length(AText))) or not IsWordByte(AnsiChar(AText[I + L]))) then
    begin
      Result := True;
      Exit;
    end;
end;

function CountValueLeaks(const AValues: TFileValues; ADiags: TLandrixGaebDiagnostics;
  out AFirst: string): Integer;
var
  I: TLandrixGaebListIndex;
  J: Integer;
  Msg: TLandrixXmlUtf8;
begin
  Result := 0;
  AFirst := '';
  if ADiags = nil then
    Exit;
  for I := 0 to ADiags.Count - 1 do
  begin
    Msg := LandrixXmlStringToUtf8(ADiags[I].Message);
    for J := 0 to Integer(High(AValues)) do
      if ContainsWord(Msg, AValues[J]) then
      begin
        if Result = 0 then
          AFirst := ADiags[I].RuleId + ' contains a value of ' + IntToStr(Integer(Length(AValues[J]))) + ' bytes';
        Inc(Result);
        Break;
      end;
  end;
end;

procedure CheckNoFileValues(const ASource: TLandrixXmlUtf8; ADiags: TLandrixGaebDiagnostics;
  const AContext: string);
var
  First: string;
begin
  CheckEquals(0, CountValueLeaks(FileValues(ASource), ADiags, First),
    AContext + ': no message contains a value of the file (' + First + ')');
end;

function ReadFileBytes(const AFileName: string): TLandrixXmlUtf8;
var
  Stream: TFileStream;
begin
  Result := '';
  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    SetLength(Result, Integer(Stream.Size));
    if Stream.Size > 0 then
      Stream.ReadBuffer(Result[1], Integer(Stream.Size));
  finally
    Stream.Free;
  end;
end;

end.
