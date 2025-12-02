param(
  [string]$Root = "$env:GITHUB_WORKSPACE"
)

$repoRoot = if ($Root) { $Root } else { (Get-Location).Path }
$cellRoot = Join-Path $repoRoot "Cell2Fire"
$incDir = Join-Path $cellRoot "include"
$vcpkgDir = Join-Path $incDir "vcpkg"

New-Item -ItemType Directory -Force -Path $incDir | Out-Null
if (-not (Test-Path (Join-Path $vcpkgDir ".git"))) {
  git clone https://github.com/microsoft/vcpkg.git $vcpkgDir
}

Push-Location $vcpkgDir
./bootstrap-vcpkg.bat
$commit = (git rev-parse HEAD).Trim()
Pop-Location

$manifestPath = Join-Path $cellRoot "vcpkg.json"
(Get-Content $manifestPath -Raw) -replace 'PLACEHOLDER_BASELINE', $commit | Set-Content $manifestPath

Push-Location $cellRoot
& "$vcpkgDir\vcpkg.exe" install --triplet x64-windows
& "$vcpkgDir\vcpkg.exe" integrate install
& "$vcpkgDir\vcpkg.exe" list | Tee-Object -FilePath (Join-Path $repoRoot 'binaries\vcpkg-versions.txt')
Pop-Location

Write-Host "vcpkg setup complete with baseline $commit"
