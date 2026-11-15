{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Single-byte code pages of the older GAEB formats: Windows-1252 (ANSI),
  code page 850 (DOS Latin-1, the OEM code page of German systems) and
  code page 437 (the original DOS code page). Tables only; no locale and
  no operating system call is involved.

  DE: Einbyte-Codepages der aelteren GAEB-Formate: Windows-1252 (ANSI),
  Codepage 850 (DOS Latin-1, OEM-Codepage deutscher Systeme) und Codepage
  437 (urspruengliche DOS-Codepage). Nur Tabellen, keine Locale und kein
  Betriebssystemaufruf. }

{ API: internal. May change in any release, also after 1.0; use the
  stable units instead (see README).
  DE: API: intern. Kann sich in jeder Version aendern, auch nach 1.0;
  stattdessen die stabilen Units verwenden (siehe README). }

unit LandrixGaebCharsets;

{$I LandrixGaeb.inc}

interface

type
  { A single-byte code page.
    DE: Eine Einbyte-Codepage. }
  TLandrixGaebCodePage = (gcpWindows1252, gcpCp850, gcpCp437);

{ Unicode code point of byte AByte in code page ACodePage. Bytes below $80
  are ASCII in all three; the five bytes Windows-1252 leaves undefined keep
  their value (as LandrixXml does).
  DE: Unicode-Codepunkt des Bytes AByte in der Codepage ACodePage. Bytes
  unter $80 sind in allen dreien ASCII; die fuenf in Windows-1252
  undefinierten Bytes behalten ihren Wert (wie in LandrixXml). }
function LandrixGaebCodePointOfByte(AByte: Byte; ACodePage: TLandrixGaebCodePage): Cardinal;

implementation

const
  { Windows-1252, bytes $80-$9F; $A0-$FF are U+00A0-U+00FF. }
  Cp1252High: array[$80..$9F] of Word = (
    $20AC, $0081, $201A, $0192, $201E, $2026, $2020, $2021,
    $02C6, $2030, $0160, $2039, $0152, $008D, $017D, $008F,
    $0090, $2018, $2019, $201C, $201D, $2022, $2013, $2014,
    $02DC, $2122, $0161, $203A, $0153, $009D, $017E, $0178);

  { Code page 850, bytes $80-$FF. }
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

  { Code page 437, bytes $80-$FF. }
  Cp437High: array[$80..$FF] of Word = (
    $00C7, $00FC, $00E9, $00E2, $00E4, $00E0, $00E5, $00E7,
    $00EA, $00EB, $00E8, $00EF, $00EE, $00EC, $00C4, $00C5,
    $00C9, $00E6, $00C6, $00F4, $00F6, $00F2, $00FB, $00F9,
    $00FF, $00D6, $00DC, $00A2, $00A3, $00A5, $20A7, $0192,
    $00E1, $00ED, $00F3, $00FA, $00F1, $00D1, $00AA, $00BA,
    $00BF, $2310, $00AC, $00BD, $00BC, $00A1, $00AB, $00BB,
    $2591, $2592, $2593, $2502, $2524, $2561, $2562, $2556,
    $2555, $2563, $2551, $2557, $255D, $255C, $255B, $2510,
    $2514, $2534, $252C, $251C, $2500, $253C, $255E, $255F,
    $255A, $2554, $2569, $2566, $2560, $2550, $256C, $2567,
    $2568, $2564, $2565, $2559, $2558, $2552, $2553, $256B,
    $256A, $2518, $250C, $2588, $2584, $258C, $2590, $2580,
    $03B1, $00DF, $0393, $03C0, $03A3, $03C3, $00B5, $03C4,
    $03A6, $0398, $03A9, $03B4, $221E, $03C6, $03B5, $2229,
    $2261, $00B1, $2265, $2264, $2320, $2321, $00F7, $2248,
    $00B0, $2219, $00B7, $221A, $207F, $00B2, $25A0, $00A0);

function LandrixGaebCodePointOfByte(AByte: Byte; ACodePage: TLandrixGaebCodePage): Cardinal;
begin
  if AByte < $80 then
    Result := AByte
  else
    case ACodePage of
      gcpCp850:
        Result := Cp850High[AByte];
      gcpCp437:
        Result := Cp437High[AByte];
    else
      if AByte <= $9F then
        Result := Cp1252High[AByte]
      else
        Result := AByte;
    end;
end;

end.
