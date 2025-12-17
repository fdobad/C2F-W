# tech tests

## mt19937 random number generator

The purpose of these tests is to assure that random generated numbers are cross platform consistent.

Two tests are included, running the same distributions used in Cell2Fire, but changing the origin of the random library.

One uses boost the other just std::random.

These tests can be run on https://github.com/fdobad/C2F-W/actions/workflows/mt19937-coordinator.yml and https://github.com/fdobad/C2F-W/actions/workflows/mt19937-coordinator-boost.yml manually as they have a workflow_dispatch directive.

On 2025-12-02 Only boost is cross platform!

When std::random get's consistent then boost dependency can be dropped easing the building times and dependencies!


## split_any_of_compare

The code used boost::algorithm: split and string to do a basic string manipulation. In behalf of reducing complexity and compilation times, this test is to replace it. 

Compile and run the standalone benchmark that compares a minimal splitter vs Boost.Algorithm.

Open a cmd terminal (from repo root), using the VS Dev Cmd environment:

Note:
- Boost.Algorithm is header-only, so no extra libraries are required to link.
- The main project no longer depends on Boost.Algorithm via vcpkg. If you want to build this tech test, install headers locally (does not affect the project manifest):

```
call "C:\Program Files\Microsoft Visual Studio\18\Community\Common7\Tools\VsDevCmd.bat"

vcpkg install boost-algorithm --triplet x64-windows

rem Prefer project-local vcpkg headers installed by manifest
cl /nologo /std:c++17 /O2 /EHsc ^
    /I "Cell2Fire\vcpkg_installed\x64-windows\include" ^
    test\tech\split_any_of_compare.cpp ^
    /Fe:test\tech\split_any_of_compare.exe

rem Run it
test\tech\split_any_of_compare.exe
```

If you use a global vcpkg instead of the project-local one, replace the include path with:

```
/I "C:\vcpkg\installed\x64-windows\include"
```



### Replacement plan (project-wide)

- Scope: Replace `boost::algorithm::split(..., boost::is_any_of(delims), ...)` with a small local helper that mimics behavior.
- Helper API: `std::vector<std::string> split_any_of(std::string_view s, std::string_view delims, bool compress=false)`.
    - `compress=false` preserves empty tokens (matches current code paths).
    - `compress=true` would collapse consecutive delimiters, not needed today.
- Affected code today:
    - `Cell2Fire/ReadCSV.cpp`: three calls that split lines using `this->delimeter` for CSV/ASC parsing.
    - Header-only includes to remove where unused: `Cell2Fire/ReadCSV.h`, `Cell2Fire/WriteCSV.h`, `Cell2Fire/WriteCSV.cpp`.
- Implementation steps:
    1) Add `split_any_of` implementation inside `ReadCSV.cpp` (file-local) to avoid new headers.
    2) Replace `boost::algorithm::split(vec, line, boost::is_any_of(this->delimeter));` with `vec = split_any_of(line, this->delimeter, false);`.
    3) Drop `#include <boost/algorithm/string.hpp>` from files that no longer use it.
    4) Rebuild and run Windows tests; spot-check CSV/ASC inputs for identical tokenization.
- Finding all occurrences:
    - Search explicit calls: `boost::algorithm::split`, `is_any_of(`, `token_compress_on|off`.
    - Search potential unqualified uses in files that include `boost/algorithm/string.hpp`.
    - Verify delimiters: inspect the argument passed to `is_any_of(...)` (usually `this->delimeter`).
- Rollback: Revert the helper and re-add Boost includes if any regression is observed.
