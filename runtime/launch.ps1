$main = Get-ChildItem -LiteralPath $PSScriptRoot -Filter "*.ps1" |
  Where-Object { $_.Name -ne "launch.ps1" } |
  Select-Object -First 1

if ($null -eq $main) {
  exit 1
}

& $main.FullName @args
exit $LASTEXITCODE
