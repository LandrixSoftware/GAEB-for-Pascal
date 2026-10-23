{
  GAEB-for-Pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}

{ Central compiler switches. Included at the top of every unit, directly
  after the unit header.

  Defines set here:
    LANDRIXGAEB_UNICODE  Delphi 2009 or later: the native string is UTF-16
                         (string = UnicodeString, Char = WideChar). Not
                         defined on Delphi 6-2007 and not on FPC. It
                         describes the native string only: TLandrixGaebString
                         is UTF-16 and lossless on every compiler.

  DE: Zentrale Compiler-Schalter. Werden in jeder Unit direkt nach dem
  Unit-Kopf eingebunden. LANDRIXGAEB_UNICODE ist ab Delphi 2009 gesetzt:
  Der native string ist UTF-16 (string = UnicodeString, Char = WideChar).
  Unter Delphi 6 bis 2007 und unter FPC ist er nicht gesetzt. Er beschreibt
  nur den nativen string: TLandrixGaebString ist unter jedem Compiler UTF-16
  und verlustfrei. }

{$IFDEF FPC}
  {$MODE DELPHI}
  {$H+}
  { Note 6058 "call to subroutine marked as inline is not inlined" is about
    RTL routines (Move, CompareMem) on some targets, not about our code. }
  {$WARN 6058 OFF}
{$ENDIF}

{$B-} { short-circuit boolean evaluation }
{$H+} { long strings }
{$J-} { typed constants are read-only }
{$T-} { untyped @ operator, as in default Delphi projects }
{$X+} { extended syntax }

{$IFNDEF FPC}
  {$IF CompilerVersion >= 20.0}
    { Delphi 2009+: string = UnicodeString, Char = WideChar }
    {$DEFINE LANDRIXGAEB_UNICODE}
  {$IFEND}
{$ENDIF}
