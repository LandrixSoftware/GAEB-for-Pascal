{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Coverage of the model (plan, phase 1 step 9): the documents of
  tools/coverage/make-coverage-cases.py (tests/data/coverage) hold every
  element and attribute of the six targets. Each one must read without a
  diagnostic, pass the content model check, go through the rules without
  an exception and come back unchanged from the writer. }

unit LandrixGaebTestCoverage;

{$I LandrixGaeb.inc}

interface

uses
  LandrixXmlBase;

{ Canonical form of a document for comparison, in UTF-8, one token per
  line: elements by namespace URI and local name with their attributes
  (expanded names, sorted, without namespace declarations), and texts as
  they are; whitespace-only text (formatting) is dropped. Line breaks and
  backslashes in values are escaped, so text cannot look like a token. }
function CanonicalXml(const ASource: TLandrixXmlUtf8): TLandrixXmlUtf8;

procedure Register;

implementation

uses
  SysUtils,
  Classes,
  LandrixXmlReader,
  LandrixGaebTypes,
  LandrixGaebDiagnostics,
  LandrixGaebDetect,
  LandrixGaebXmlModel,
  LandrixGaebXmlReader,
  LandrixGaebXmlWriteBase,
  LandrixGaebXmlWriter,
  LandrixGaebXmlCheck,
  LandrixGaebRules,
  LandrixGaebTestNoValues,
  LandrixGaebTestFramework;

function CoverageDir: string;
begin
  Result := RepositoryRoot + 'tests' + PathDelim + 'data' + PathDelim + 'coverage' + PathDelim;
end;

function Escape(const S: TLandrixXmlUtf8): TLandrixXmlUtf8;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Integer(Length(S)) do
    if S[I] = #92 then
      Result := Result + #92#92
    else if S[I] = #10 then
      Result := Result + #92'n'
    else if S[I] = #13 then
      Result := Result + #92'r'
    else
      Result := Result + Copy(S, I, 1);
end;

function IsBlank(const S: TLandrixXmlUtf8): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to Integer(Length(S)) do
    if not ((S[I] = ' ') or (S[I] = #9) or (S[I] = #10) or (S[I] = #13)) then
      Exit;
  Result := True;
end;

function ExpandedName(const AUri, ALocal: TLandrixXmlUtf8): TLandrixXmlUtf8;
begin
  Result := '{' + AUri + '}' + ALocal;
end;

function CanonicalXml(const ASource: TLandrixXmlUtf8): TLandrixXmlUtf8;
const
  XmlnsUri: TLandrixXmlUtf8 = 'http://www.w3.org/2000/xmlns/';
var
  Reader: TLandrixXmlReader;
  Attrs: array of TLandrixXmlUtf8;
  I, J, N: Integer;
  Text, A, Line: TLandrixXmlUtf8;
begin
  Result := '';
  Attrs := nil;
  Reader := TLandrixXmlReader.Create;
  try
    Reader.LoadFromUtf8(ASource);
    Text := '';
    while Reader.Read do
      case Reader.TokenType of
        xttText, xttCData:
          Text := Text + Reader.ValueUtf8;
        xttStartElement, xttEndElement:
          begin
            if not IsBlank(Text) then
              Result := Result + 'T ' + Escape(Text) + #10;
            Text := '';
            if Reader.TokenType = xttEndElement then
            begin
              { the reader also gives an end token for an empty element }
              Result := Result + 'E' + #10;
              Continue;
            end;
            { attributes by expanded name, insertion sort }
            N := 0;
            SetLength(Attrs, Reader.AttributeCount);
            for I := 0 to Reader.AttributeCount - 1 do
            begin
              if Reader.AttributeNamespaceUriUtf8(I) = XmlnsUri then
                Continue;
              A := ExpandedName(Reader.AttributeNamespaceUriUtf8(I), Reader.AttributeLocalNameUtf8(I)) + '=' +
                Escape(Reader.AttributeValueUtf8(I));
              J := N;
              while (J > 0) and (Attrs[J - 1] > A) do
              begin
                Attrs[J] := Attrs[J - 1];
                Dec(J);
              end;
              Attrs[J] := A;
              Inc(N);
            end;
            Line := 'S ' + ExpandedName(LandrixXmlSpanToUtf8(Reader.NamespaceUriSpan),
              LandrixXmlSpanToUtf8(Reader.LocalNameSpan));
            for I := 0 to N - 1 do
              Line := Line + ' ' + Attrs[I];
            Result := Result + Line + #10;
          end;
      else
        ;
      end;
  finally
    Reader.Free;
  end;
end;

function Problems(ADiags: TLandrixGaebDiagnostics): Integer;
var
  I: TLandrixGaebListIndex;
begin
  Result := 0;
  for I := 0 to ADiags.Count - 1 do
    if ADiags[I].Severity >= gsWarning then
      Inc(Result);
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

{ The next line of S from position APos (moved past the line break). }
function NextLine(const S: TLandrixXmlUtf8; var APos: Integer): TLandrixXmlUtf8;
var
  Start: Integer;
begin
  Start := APos;
  while (APos <= Integer(Length(S))) and (S[APos] <> #10) do
    Inc(APos);
  Result := Copy(S, Start, APos - Start);
  Inc(APos);
end;

{ The first line in which two canonical forms differ, with its number;
  '' if they are equal. }
function FirstDifference(const A, B: TLandrixXmlUtf8): string;
var
  PA, PB, Line: Integer;
  SA, SB: TLandrixXmlUtf8;
begin
  Result := '';
  PA := 1;
  PB := 1;
  Line := 0;
  while (PA <= Integer(Length(A))) or (PB <= Integer(Length(B))) do
  begin
    Inc(Line);
    SA := '<end>';
    SB := '<end>';
    if PA <= Integer(Length(A)) then
      SA := NextLine(A, PA);
    if PB <= Integer(Length(B)) then
      SB := NextLine(B, PB);
    if SA <> SB then
    begin
      Result := 'line ' + IntToStr(Line) + ': expected "' + LandrixXmlUtf8ToString(SA) + '", written "' +
        LandrixXmlUtf8ToString(SB) + '"';
      Exit;
    end;
  end;
end;

procedure CheckDocument(const AName: string);
var
  Source, Output: TLandrixXmlUtf8;
  Diags: TLandrixGaebDiagnostics;
  Det: TLandrixGaebDetection;
  G: TLandrixGaebXmlGAEB;
  Target: TLandrixGaebTarget;
  Expected: TLandrixXmlUtf8;
  Ok: Boolean;
begin
  Source := ReadFileBytes(CoverageDir + AName);
  Diags := TLandrixGaebDiagnostics.Create;
  G := nil;
  try
    Ok := LandrixGaebXmlCheckBuffer(Pointer(Source), Integer(Length(Source)), Diags, Det);
    Check(Ok, AName + ' passes the check: ' + Diags.ToText);
    Diags.Clear;
    G := LandrixGaebXmlReadBuffer(Pointer(Source), Integer(Length(Source)), Diags, Det);
    CheckEquals(0, Integer(Diags.Count), AName + ': every element and attribute is in the model: ' + Diags.ToText);
    Diags.Clear;
    LandrixGaebCheckRules(G, Det.Target, Diags);
    CheckNoFileValues(Source, Diags, AName);
    { 3.3/2019-11 is read, not written: it goes to 2021-05 (same namespace) }
    Target := Det.Target;
    Expected := CanonicalXml(Source);
    if not LandrixGaebTargetIsSupported(Target, True) then
    begin
      Target := LandrixGaebTarget(gv33, ge2021_05, Target.Phase);
      Expected := ReplaceFirst(Expected, 'T 2019-11' + #10, 'T 2021-05' + #10);
    end;
    Diags.Clear;
    Output := LandrixGaebXmlWriteUtf8(G, Target, LandrixGaebXmlDefaultWriteOptions, Diags);
    { 2019-11 -> 2021-05: only the information that VersDate is replaced }
    CheckEquals(0, Problems(Diags), AName + ': written without warnings or errors: ' + Diags.ToText);
    CheckEqualsStr('', FirstDifference(Expected, CanonicalXml(Output)),
      AName + ': written unchanged');
  finally
    G.Free;
    Diags.Free;
  end;
end;

{ The canonical form keeps what matters and ignores formatting. }
procedure TestCanonical;

  procedure Same(const A, B: TLandrixXmlUtf8; const AMsg: string);
  begin
    CheckEqualsStr('', FirstDifference(CanonicalXml(A), CanonicalXml(B)), AMsg);
  end;

  procedure Differ(const A, B: TLandrixXmlUtf8; const AMsg: string);
  begin
    Check(FirstDifference(CanonicalXml(A), CanonicalXml(B)) <> '', AMsg);
  end;

begin
  Same('<a><b x="1" y="2"/></a>', '<a>' + #10 + '  <b y="2" x="1"></b>' + #10 + '</a>',
    'attribute order, empty element and indentation are formatting');
  Same('<a xmlns="urn:x"><b/></a>', '<p:a xmlns:p="urn:x"><p:b/></p:a>', 'prefixes are not compared');
  Same('<a>x<![CDATA[y]]></a>', '<a>xy</a>', 'text and CDATA joined');
  Differ('<p><span>A&#10;E&#10;S span&#10;T B</span></p>', '<p><span>A</span><span>B</span></p>',
    'text cannot look like a token');
  Differ('<a><s>A </s><s>B</s></a>', '<a><s>A</s><s>B</s></a>', 'whitespace in text is kept');
  Differ('<a xmlns:p="urn:p" xmlns:q="urn:q"><p:x/></a>', '<a xmlns:p="urn:p" xmlns:q="urn:q"><q:x/></a>',
    'elements by namespace');
  Differ('<a x="1"/>', '<a x="2"/>', 'attribute values');
end;

procedure TestDocuments;
var
  SR: TSearchRec;
  Names: TStringList;
  I: Integer;
begin
  Names := TStringList.Create;
  try
    if FindFirst(CoverageDir + '*.x8?', faAnyFile, SR) = 0 then
    try
      repeat
        Names.Add(SR.Name);
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
    Names.Sort;
    CheckEquals(18, Names.Count, 'six targets, one minimal and two full documents each');
    for I := 0 to Names.Count - 1 do
      CheckDocument(Names[I]);
  finally
    Names.Free;
  end;
end;

procedure Register;
begin
  RegisterTest('Coverage.Canonical', TestCanonical);
  RegisterTest('Coverage.Documents', TestDocuments);
end;

end.
