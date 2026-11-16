{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Converts a file of the old formats GAEB 90 (.D8x) or GAEB DA 2000
  (.P8x) into GAEB DA XML 3.3 (.X8x). The format is recognised by the
  content, not by the extension. The program prints what it found
  (format, version, phase), what reading reported (counted by rule) and
  the total of the bill. A GAEB 90 bid often carries only prices (records
  23 without 21), so it cannot tell which items count; given the request
  as third argument, the missing totals are computed with the kinds of the
  request.

  DE: Wandelt eine Datei der alten Formate GAEB 90 (.D8x) oder GAEB DA
  2000 (.P8x) in GAEB DA XML 3.3 (.X8x). Das Format wird am Inhalt
  erkannt, nicht an der Endung. Das Programm gibt aus, was es gefunden hat
  (Format, Version, Phase), was das Lesen gemeldet hat (je Regel gezaehlt)
  und die Summe des LV. Ein Angebot in GAEB 90 traegt oft nur Preise
  (Saetze 23 ohne 21) und kann deshalb nicht sagen, welche Positionen
  zaehlen; mit der Anfrage als drittem Argument werden die fehlenden
  Summen mit den Arten der Anfrage berechnet.

  Usage / Aufruf: LegacyToXml <input> <output.x8x> [<request>] }

program LegacyToXml;

{$I LandrixGaeb.inc}

{$IFDEF MSWINDOWS}
  {$APPTYPE CONSOLE}
{$ENDIF}

uses
{$IFDEF FPC}
  {$IFDEF UNIX}
  { converts between UTF-8 and the native string on Unix (output of texts)
    DE: wandelt unter Unix zwischen UTF-8 und dem nativen String (Ausgabe
    von Texten) }
  cwstring,
  {$ENDIF}
{$ENDIF}
  SysUtils,
  Classes,
  LandrixXmlBase,
  LandrixGaebTypes,
  LandrixGaebDiagnostics,
  LandrixGaebDetect,
  LandrixGaebBoQ,
  LandrixGaebProcess;

{ Texts of the library are UTF-16; the console takes the native string.
  DE: Texte der Bibliothek sind UTF-16; die Konsole nimmt den nativen
  String. }
function S(const AText: TLandrixGaebString): string;
begin
  Result := LandrixXmlUtf8ToString(LandrixXmlWideToUtf8(AText));
end;

{ A decimal as written in the document, '-' if absent.
  DE: Eine Dezimalzahl wie im Dokument, '-' wenn sie fehlt. }
function D(const AValue: TLandrixGaebDecimal): string;
begin
  if AValue.HasValue then
    Result := LandrixXmlUtf8ToString(AValue.Text)
  else
    Result := '-';
end;

{ The findings counted per rule; the messages of the library name rules,
  keys and lines, never content of the file.
  DE: Die Befunde je Regel gezaehlt; die Meldungen der Bibliothek nennen
  Regeln, Schluessel und Zeilen, nie Inhalt der Datei. }
procedure PrintFindings(ADiags: TLandrixGaebDiagnostics);
var
  Rules: TStringList;
  Counts: array of Integer;
  I, K: Integer;
begin
  Rules := TStringList.Create;
  try
    Counts := nil;
    for I := 0 to Integer(ADiags.Count) - 1 do
    begin
      K := Rules.IndexOf(ADiags[I].RuleId);
      if K < 0 then
      begin
        K := Rules.Add(ADiags[I].RuleId);
        SetLength(Counts, K + 1);
        Counts[K] := 0;
      end;
      Inc(Counts[K]);
    end;
    for I := 0 to Rules.Count - 1 do
      WriteLn('  ', Rules[I], ' x', Counts[I]);
  finally
    Rules.Free;
  end;
end;

procedure Run(const AInput, AOutput, ARequest: string);
var
  Bill, Request: TLandrixGaebBillOfQuantities;
  Matching: TLandrixGaebMatching;
  Diags: TLandrixGaebDiagnostics;
  Options: TLandrixGaebXmlWriteOptions;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  Bill := nil;
  Request := nil;
  try
    { LoadFromFile reads GAEB DA XML, GAEB DA 2000 and GAEB 90; the
      document is always the GAEB DA XML 3.3 model
      DE: LoadFromFile liest GAEB DA XML, GAEB DA 2000 und GAEB 90; das
      Dokument ist immer das Modell GAEB DA XML 3.3 }
    Bill := TLandrixGaebBillOfQuantities.LoadFromFile(AInput, Diags, 0);
    { Source describes the file as found
      DE: Source beschreibt die Datei, wie sie gefunden wurde }
    WriteLn(AInput, ': ', LandrixGaebFormatToStr(Bill.SourceFormat), ', version ',
      Bill.Source.SourceVersion, ', phase ', Bill.Source.SourcePhase, ' -> GAEB DA XML ',
      LandrixXmlUtf8ToString(LandrixGaebVersionToText(Bill.OutputTarget.Version)), ' DA',
      LandrixXmlUtf8ToString(LandrixGaebPhaseToDP(Bill.OutputTarget.Phase)));
    WriteLn('project: ', S(Bill.ProjectName), ', bill: ', S(Bill.BoQName));

    { a bid without the kinds of its items (GAEB-BOQ-004): the request
      tells which items count
      DE: ein Angebot ohne die Arten seiner Positionen (GAEB-BOQ-004): die
      Anfrage sagt, welche Positionen zaehlen }
    if (Diags.CountOf('GAEB-BOQ-004') > 0) and (ARequest <> '') then
    begin
      Request := TLandrixGaebBillOfQuantities.LoadFromFile(ARequest, Diags, 0);
      Matching := TLandrixGaebMatching.Create(Request, Bill);
      try
        WriteLn('totals computed with the request: ', LandrixGaebFillMissingTotals(Bill, Matching, Diags));
      finally
        Matching.Free;
      end;
    end;
    WriteLn('total of the bill: ', D(Bill.Total));
    { GAEB 90 knows owner and bidder by a name line only; GAEB DA XML
      requires street, postal code and town, which the program that passes
      the file on completes
      DE: GAEB 90 kennt Auftraggeber und Bieter nur ueber eine Namenszeile;
      GAEB DA XML verlangt Strasse, Postleitzahl und Ort, die das
      weitergebende Programm ergaenzt }
    if Bill.Owner.Exists and (Bill.Owner.Street = '') then
      WriteLn('note: the address of the owner has no street, postal code and town; complete them');
    if Bill.Contractor.Exists and (Bill.Contractor.Street = '') then
      WriteLn('note: the address of the bidder has no street, postal code and town; complete them');

    { what GAEB DA XML does not allow in the phase (rare for the old
      formats) is left out and reported (GAEB-WRT-001) instead of refusing
      the whole file
      DE: was GAEB DA XML in der Phase nicht erlaubt (bei den alten
      Formaten selten), wird weggelassen und gemeldet (GAEB-WRT-001),
      statt die ganze Datei zu verweigern }
    Options := Bill.WriteOptions;
    Options.Mode := gwmBestEffort;
    Bill.WriteOptions := Options;
    Bill.SaveToFile(AOutput, Diags);
    WriteLn('written: ', AOutput);
  finally
    { findings of reading and writing, also after a failure
      DE: Befunde von Lesen und Schreiben, auch nach einem Fehler }
    PrintFindings(Diags);
    Request.Free;
    Bill.Free;
    Diags.Free;
  end;
end;

begin
  if (ParamCount < 2) or (ParamCount > 3) then
  begin
    WriteLn('Usage: LegacyToXml <input> <output.x8x> [<request>]');
    ExitCode := 2;
    Exit;
  end;
  try
    if ParamCount = 3 then
      Run(ParamStr(1), ParamStr(2), ParamStr(3))
    else
      Run(ParamStr(1), ParamStr(2), '');
  except
    on E: Exception do
    begin
      WriteLn(E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
