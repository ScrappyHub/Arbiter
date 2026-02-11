param(
  [Parameter(Mandatory=$true)][string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path (Join-Path $RepoRoot "scripts") "_lib_arbiter_v1.ps1")

Arbiter-NotImplemented "selftest_arbiter_v1.ps1 (will execute examples/watchtower_ingest through evaluator)"
