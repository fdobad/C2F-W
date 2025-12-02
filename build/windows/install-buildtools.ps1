param(
  [string]$InstallPath = "C:\BuildTools",
  [ValidateSet('Windows11')][string]$Sdk = 'Windows11',
  [switch]$IncludeCMake,
  [switch]$IncludeTestTools,
  [switch]$Verbose
)

Write-Host "Installing Visual Studio Build Tools to $InstallPath"

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
  Write-Error "This script must be run as Administrator."
  exit 1
}

$url = "https://aka.ms/vs/17/release/vs_buildtools.exe"
$exe = "$env:TEMP\vs_buildtools.exe"
Invoke-WebRequest -Uri $url -OutFile $exe

$sdkComponent = 'Microsoft.VisualStudio.Component.Windows11SDK.22621'
$components = @(
  'Microsoft.VisualStudio.Workload.VCTools',
  'Microsoft.VisualStudio.Component.VC.Tools.x86.x64',
  $sdkComponent
)
if ($IncludeCMake) { $components += 'Microsoft.VisualStudio.Component.VC.CMake.Project' }
if ($IncludeTestTools) { $components += 'Microsoft.VisualStudio.Component.TestTools.BuildTools' }

Write-Host "Installing components: $($components -join ', ')" 
Write-Host "Selected SDK component: $sdkComponent"

$installLog = Join-Path $InstallPath "install.log"

# Build a flattened argument array to avoid code 87 (invalid params)
$argList = @("--quiet","--wait","--norestart","--nocache")
foreach ($c in $components) { $argList += @("--add", $c) }
$argList += @("--installPath", $InstallPath, "--log", $installLog)

$p = Start-Process -FilePath $exe -ArgumentList $argList -PassThru -Wait
Write-Host "Installer exited with code $($p.ExitCode)"

if ($p.ExitCode -ne 0) {
  Write-Error "Build Tools installation failed. See log at $installLog"
  if (Test-Path $installLog) {
    Write-Host "Last 100 lines of installer log:" -ForegroundColor Yellow
    try { Get-Content -Path $installLog -Tail 100 } catch { Write-Warning "Unable to read $installLog : $($_)" }
  }
  exit $p.ExitCode
}

Write-Host "Verifying toolchain..."
$vswhere = "$env:ProgramFiles(x86)\Microsoft Visual Studio\Installer\vswhere.exe"
if (!(Test-Path $vswhere)) { Write-Warning "vswhere.exe not found after install." }
else {
  $vs = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild -property installationPath
  if (-not $vs) { Write-Warning "No VS installation reported by vswhere." } else { Write-Host "VS install path: $vs" }
  $msbuild = Join-Path $vs "MSBuild\Current\Bin\MSBuild.exe"
  if (Test-Path $msbuild) {
    & $msbuild -version | Tee-Object -FilePath (Join-Path $InstallPath 'msbuild-version.txt') | Out-Null
  } else { Write-Warning "MSBuild.exe not found." }
}

# Collect expected tool locations
$cl = Get-Command cl.exe -ErrorAction SilentlyContinue
$rc = Get-Command rc.exe -ErrorAction SilentlyContinue
$mt = Get-Command mt.exe -ErrorAction SilentlyContinue

# Locate kernel32.lib within Windows Kits
$kernel32 = Get-ChildItem "C:\Program Files (x86)\Windows Kits" -Recurse -ErrorAction SilentlyContinue -Filter kernel32.lib | Select-Object -First 1

$missing = @()
if (-not $cl) { $missing += 'cl.exe (MSVC compiler)' }
if (-not $rc) { $missing += 'rc.exe (Resource Compiler - Windows SDK)' }
if (-not $mt) { $missing += 'mt.exe (Manifest Tool - Windows SDK)' }
if (-not $kernel32) { $missing += 'kernel32.lib (Windows SDK libs)' }

if ($missing.Count -gt 0) {
  Write-Warning "Missing components: $($missing -join ', ')"
  Write-Warning "Install may be incomplete. Check $InstallPath\install.log and consider rerunning with elevated privileges."
  Exit 2
}

Write-Host "Toolchain verification succeeded." 
if ($Verbose) {
  Write-Host "cl.exe: $($cl.Source)"
  Write-Host "rc.exe: $($rc.Source)"
  Write-Host "mt.exe: $($mt.Source)"
  Write-Host "kernel32.lib: $($kernel32.FullName)"
}

# Persist a summary file
$summary = @(
  "VSInstallPath=$vs",
  "MSBuild=$msbuild",
  "cl=$($cl.Source)",
  "rc=$($rc.Source)",
  "mt=$($mt.Source)",
  "kernel32=$($kernel32.FullName)",
  "SDKComponent=$sdkComponent",
  "Timestamp=$(Get-Date -Format o)"
)
$summary | Set-Content (Join-Path $InstallPath 'toolchain-summary.txt')

Write-Host "Build Tools installation complete and validated."
