# Contributing to GAEB-for-pascal

Thank you for your interest in contributing to **GAEB-for-pascal**.

Bug reports, test cases, documentation improvements and pull requests are welcome.
Please read the following guidelines before submitting code.

By submitting a pull request or other contribution, you agree to the contribution licensing terms described below.

## Project scope

GAEB-for-pascal is a Pascal library for reading, writing and processing construction
data exchange files according to the GAEB standard (Gemeinsamer Ausschuss Elektronik
im Bauwesen), in particular GAEB DA XML.

The library supports Delphi and Free Pascal where documented in the README.

## Before submitting a pull request

Please:

1. Keep changes focused on a single issue or feature where possible.
2. Avoid unrelated formatting or whitespace changes.
3. Follow the style of the surrounding source code.
4. Add or update tests for functional changes.
5. Make sure existing tests still pass.
6. Clearly describe what was changed and why.

Changes affecting generated GAEB files should, where applicable, be validated against the official GAEB XML schemas of the respective version and exchange phase (DA).

## Compatibility

All library code must compile unchanged with **Delphi 6 through Delphi 13** and **Free Pascal 3.2.2, 3.2.4 and 3.3.1**. XML is handled exclusively by [LandrixXML for Pascal](https://github.com/LandrixSoftware/LandrixXML-for-Pascal) (Git submodule `external/landrix-xml`); the language subset is the same:

* Units: only `SysUtils`, `Classes`, `Contnrs`, `Types` (Delphi only, where required), LandrixXml units and own units. Unqualified unit names; unit names contain no dot.
* Not allowed: generics, anonymous methods, `for ... in`, `Exit(Value)`, `strict private/protected`, records with methods, class and record helpers, operator overloading, `inline`, `class var`, nested types, inline `var` declarations, `{$REGION}`.
* Not allowed: `TStringBuilder`, `TEncoding`, `TFormatSettings`, `PosEx`, `CharInSet`, `RawByteString`, `NativeInt`, `NativeUInt`, `TBytes`, `UInt64`, `UTF8ToString`.
* Not allowed: MSXML, `Xml.*`, `fcl-xml` or any other XML library.
* `{$IF}` is always closed with `{$IFEND}`; `CompilerVersion` comparisons use float constants (`20.0`).
* No dependency on the current locale. Quantities, prices and dates are converted with locale-independent helpers; amounts are never calculated or rounded via floating point.
* Source files contain only ASCII characters; use `#$xx` constants for other characters.

Where differences between Delphi and Free Pascal are required, use conditional compilation in the central include file and keep the common implementation shared.

Changes that intentionally break the public API should be discussed before implementation.

## File headers

Every new source file starts with this header:

```pascal
{
  GAEB-for-pascal

  Copyright (C) 2026 Landrix Software GmbH & Co. KG

  This file is dual-licensed under:
  - GNU GPL version 3 or later; or
  - the Landrix Software Commercial License.

  See LICENSE and commercial.license.md.

  SPDX-License-Identifier: GPL-3.0-or-later OR LicenseRef-Landrix-Commercial
}
```

## Comments and documentation

Code is written in English: identifiers, exception and test messages and purely technical comments. GAEB element names keep the spelling of the schema (`BoQ`, `Itemlist`, `Qty`, ...).

The code is documented directly in the source, in English and German:

* In the library sources (`source/`), every public declaration in an `interface` section and every GAEB business rule in an implementation (exchange phase rules, mandatory elements, special cases) has a comment block: first English, then a paragraph starting with `DE:` in German.
* Purely technical comments inside implementations are English only, and so are tests and tools.
* Self-explanatory code needs no comment.
* Sources stay ASCII-only, so German umlauts are written as `ae`, `oe`, `ue` and `ss`.

```pascal
{ Quantity of a bill of quantities item (element Qty, three decimals).
  DE: Menge einer LV-Position (Element Qty, drei Nachkommastellen). }
```

Where practical, references to the GAEB version (e.g. 3.3), the exchange phase (e.g. DA 83, DA 84) and the XML element path are encouraged.

Do not commit GAEB specification documents, schemas or other copyrighted standard texts, and do not copy text from them into comments.

## Licensing of the project

GAEB-for-pascal is dual-licensed.

Users may use the project under either:

1. the **GNU General Public License version 3 or later (GPL-3.0-or-later)**; or
2. the **Landrix Software Commercial License**.

The commercial license allows the library to be used as part of proprietary applications without the copyleft requirements of the GPL.

## Licensing of contributions

To preserve this dual-licensing model, contributions must be available for use under both licensing options.

By intentionally submitting a contribution for inclusion in GAEB-for-pascal, you agree to the following terms:

You retain the copyright in your contribution.

You grant **Landrix Software GmbH & Co. KG** a perpetual, worldwide, non-exclusive, irrevocable, royalty-free license to:

* use,
* reproduce,
* modify,
* prepare derivative works of,
* publicly display,
* publicly perform,
* distribute,
* sublicense, and
* otherwise incorporate

your contribution, in source or binary form, as part of GAEB-for-pascal and related versions of the project.

This license includes the explicit right to distribute and sublicense your contribution:

* under the GNU General Public License version 3 or any later version;
* under the Landrix Software Commercial License; and
* as part of commercial or proprietary distributions of GAEB-for-pascal offered by Landrix Software.

This grant does **not** transfer ownership of your copyright to Landrix Software.

## Patent license

Where you own or control patent claims that would necessarily be infringed by your contribution alone or by its combination with the project as submitted, you grant Landrix Software and recipients of the contribution a perpetual, worldwide, non-exclusive, royalty-free patent license to make, use, offer for sale, sell, import and otherwise use the contribution as part of the project.

This patent grant applies only to patent claims that you have the right to license.

## Your authority to contribute

By submitting a contribution, you represent that:

* you created the contribution yourself or otherwise have the legal right to submit it under these terms;
* the contribution does not knowingly include code or other material that you are not authorized to provide;
* you have the authority to grant the rights described above.

If your contribution was created as part of your employment or on behalf of a company or other organization, you are responsible for ensuring that you are authorized to submit it under these terms.

Please do not submit code copied from another project unless its license is compatible with this project and its origin and license are clearly identified.

## Third-party code

If a contribution contains or is derived from third-party code, please state this clearly in the pull request and provide:

* the original project or source;
* the copyright holder, where known;
* the applicable license;
* a link to the original source where possible.

Do not submit GPL-only third-party code if Landrix Software would not also have the right to include that code in the commercially licensed version of the project.

Permissively licensed code, such as code under the MIT, BSD or Apache License 2.0, may be acceptable, but applicable attribution and redistribution requirements must be preserved.

## Test data

Never submit real bills of quantities, tenders or files containing personal data, prices of real projects or credentials. Test files must use synthetic data and be redistributable.

## Automated or AI-assisted contributions

Code created with automated development tools or generative AI may be submitted, but the contributor remains responsible for the contribution.

In particular, you must ensure that:

* you have the right to submit the resulting code;
* no incompatible third-party code has been reproduced;
* the contribution has been reviewed and tested;
* the contribution complies with the licensing terms above.

Automated generation does not remove the contributor's responsibility for correctness, security or licensing.

## Pull request acceptance

Submission of a pull request does not guarantee that it will be merged.

Landrix Software may request changes, additional tests or documentation before accepting a contribution.

Once a contribution has been accepted into the project, the rights granted under the **Licensing of contributions** section are irrevocable.

## Questions

If you are unsure whether a contribution can be submitted under these terms, please open an issue before submitting the code or contact:

**Landrix Software GmbH & Co. KG**
[info@landrix.de](mailto:info@landrix.de)
