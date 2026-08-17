# Loads SUPABASE_URL / SUPABASE_ANON_KEY from .env and runs the app with them.
# Without these --dart-define flags the app boots in OFFLINE mode and signup/
# signin fail with "authUnavailable". Always launch through this script.
#
# Usage:
#   .\run.ps1                              -> flutter run (first attached device)
#   .\run.ps1 -Device R5CY927RK3K          -> flutter run -d R5CY927RK3K
#   .\run.ps1 -Command "build apk --release"
param(
  [string]$Device = "",
  [string]$Command = ""
)

$ErrorActionPreference = "Stop"
$envFile = Join-Path $PSScriptRoot ".env"
if (-not (Test-Path $envFile)) {
  Write-Error "Missing .env - create it with SUPABASE_URL and SUPABASE_ANON_KEY."
}

$values = @{}
Get-Content $envFile | ForEach-Object {
  $line = $_.Trim()
  if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
    $parts = $line.Split("=", 2)
    $values[$parts[0].Trim()] = $parts[1].Trim()
  }
}

if (-not $values["SUPABASE_URL"] -or -not $values["SUPABASE_ANON_KEY"]) {
  Write-Error "SUPABASE_URL and SUPABASE_ANON_KEY must be set in .env"
}

$defines = @(
  "--dart-define=SUPABASE_URL=$($values['SUPABASE_URL'])",
  "--dart-define=SUPABASE_ANON_KEY=$($values['SUPABASE_ANON_KEY'])"
)

if ($Command -ne "") {
  flutter $Command.Split(" ") @defines
} elseif ($Device -ne "") {
  flutter run -d $Device @defines
} else {
  flutter run @defines
}
