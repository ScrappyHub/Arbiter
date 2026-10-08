param(
  [int]$Depth = 0,
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$PolicySetPath,
  [Parameter(Mandatory=$true)][string]$InputPath,
  [Parameter(Mandatory=$true)][string]$OutDecisionPath,
  [Parameter()][string]$ReceiptPath
)
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$PolicySetPath = (Resolve-Path -LiteralPath $PolicySetPath).Path
$InputPath = (Resolve-Path -LiteralPath $InputPath).Path
$lib = Join-Path (Join-Path $RepoRoot "scripts") "_lib_arbiter_v1.ps1"
if(-not (Test-Path -LiteralPath $lib -PathType Leaf)){ throw ("MISSING_LIB: " + $lib) }
. $lib

function WriteUtf8NoBomLf([string]$Path,[string]$Text){
  $t = ($Text -replace "`r`n","`n") -replace "`r","`n"
  if(-not $t.EndsWith("`n")){ $t += "`n" }
  $dir = Split-Path -Parent $Path
  if($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)){ [void][System.IO.Directory]::CreateDirectory($dir) }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllBytes($Path, $enc.GetBytes($t))
}
$dec = Arbiter-Evaluate -RepoRoot $RepoRoot -PolicySetPath $PolicySetPath -InputPath $InputPath
$outDir = Split-Path -Parent $OutDecisionPath
if($outDir -and -not (Test-Path -LiteralPath $outDir -PathType Container)){ [void][System.IO.Directory]::CreateDirectory($outDir) }
$h = Arbiter-WriteCanonJsonFile -Path $OutDecisionPath -Obj $dec
Write-Host ("DECISION_WROTE: " + $OutDecisionPath + " " + $h) -ForegroundColor Green
if($ReceiptPath){
  $line = @{ schema="arbiter.receipt.v1"; engine="arbiter.v1"; engine_version="1.0.0"; evaluated_at=$dec["evaluated_at"]; policy_hash=$dec["policy_hash"]; input_hash=$dec["input_hash"]; decision_hash=$dec["decision_hash"]; decision=$dec["decision"]; matched_rule_id=$dec["matched_rule_id"]; reasons=@(@($dec["reasons"])) }
  Arbiter-AppendReceipt -ReceiptPath $ReceiptPath -LineObj $line
  Write-Host ("RECEIPT_APPENDED: " + $ReceiptPath) -ForegroundColor Cyan
}
