{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Converts a GAEB DA XML file to another version: GAEB DA XML 3.2
  (edition 2013-10) or 3.3 (edition 2021-05), same phase. The writer checks
  the output against the schema of the target; an element the target does
  not know is a loss (GAEB-WRT-001), and in the default mode gwmNormal the
  writer then refuses the document (WriteOptions.Mode := gwmBestEffort
  leaves such elements out and reports them).

  DE: Wandelt eine GAEB-DA-XML-Datei in eine andere Version: GAEB DA XML
  3.2 (Ausgabe 2013-10) oder 3.3 (Ausgabe 2021-05), gleiche Phase. Der
  Schreiber prueft die Ausgabe gegen das Schema des Ziels; ein Element,
  das das Ziel nicht kennt, ist ein Verlust (GAEB-WRT-001), und im
  Standardmodus gwmNormal verweigert der Schreiber dann das Dokument
  (WriteOptions.Mode := gwmBestEffort laesst solche Elemente weg und
  meldet sie).

  Usage / Aufruf: ConvertGaeb <input> <output> 3.2|3.3 }

program ConvertGaeb;

{$I LandrixGaeb.inc}

{$IFDEF MSWINDOWS}
  {$APPTYPE CONSOLE}
{$ENDIF}

uses
{$IFDEF FPC}
  {$IFDEF UNIX}
  { converts between UTF-8 and the native string on Unix (output of texts)
    DE: wandelt unter Unix zwischen UTF-8 und dem nativen String (Ausgabe von
    Texten) }
  cwstring,
  {$ENDIF}
{$ENDIF}
  SysUtils,
  LandrixXmlBase,
  LandrixGaebTypes,
  LandrixGaebDiagnostics,
  LandrixGaebBoQ;

procedure Run(const AInput, AOutput, AVersion: string);
var
  Bill: TLandrixGaebBillOfQuantities;
  Diags: TLandrixGaebDiagnostics;
  Target: TLandrixGaebTarget;
begin
  Diags := TLandrixGaebDiagnostics.Create;
  try
    Bill := TLandrixGaebBillOfQuantities.LoadFromFile(AInput, Diags, 0);
    try
      { Target is what the document is; OutputTarget what it is saved as.
        A record: change a copy and assign it as a whole.
        DE: Target ist, was das Dokument ist; OutputTarget, als was es
        gespeichert wird. Ein Record: eine Kopie aendern und als Ganzes
        zuweisen. }
      Target := Bill.Target;
      if AVersion = '3.2' then
      begin
        Target.Version := gv32;
        Target.Edition := ge2013_10;
      end
      else if AVersion = '3.3' then
      begin
        Target.Version := gv33;
        Target.Edition := ge2021_05;
      end
      else
        raise Exception.Create('unknown version ' + AVersion + ' (3.2 or 3.3)');
      Bill.OutputTarget := Target;
      Bill.SaveToFile(AOutput, Diags);
      WriteLn('converted: ', AInput, ' (', LandrixXmlUtf8ToString(LandrixGaebVersionToText(Bill.Target.Version)),
        ') -> ', AOutput, ' (', AVersion, ')');
    finally
      Bill.Free;
    end;
  finally
    { e.g. GAEB-WRT-001 for every element the target does not know; also
      when writing failed
      DE: z. B. GAEB-WRT-001 fuer jedes Element, das das Ziel nicht kennt;
      auch wenn das Schreiben gescheitert ist }
    Write(Diags.ToText);
    Diags.Free;
  end;
end;

begin
  if ParamCount <> 3 then
  begin
    WriteLn('Usage: ConvertGaeb <input> <output> 3.2|3.3');
    ExitCode := 2;
    Exit;
  end;
  try
    Run(ParamStr(1), ParamStr(2), ParamStr(3));
  except
    on E: Exception do
    begin
      WriteLn(E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;
end.
