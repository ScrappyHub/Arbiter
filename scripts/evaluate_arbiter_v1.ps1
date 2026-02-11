param(
  [Parameter(Mandatory=$true)][string]$PolicySetPath,
  [Parameter(Mandatory=$true)][string]$InputPath,
  [Parameter(Mandatory=$true)][string]$OutDecisionPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "_lib_arbiter_v1.ps1")

Arbiter-NotImplemented "evaluate_arbiter_v1.ps1 (real evaluator generation is next)"
