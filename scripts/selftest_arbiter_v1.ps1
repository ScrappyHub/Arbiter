param([Parameter(Mandatory=$true)][string]$RepoRoot)
Set-StrictMode -Version Latest
function WriteUtf8NoBomLf([string]$Path,[string]$Text){
  $t = ($Text -replace "`r`n","`n") -replace "`r","`n"
  if(-not $t.EndsWith("`n")){ $t += "`n" }
  $dir = Split-Path -Parent $Path
  if($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)){ [void][System.IO.Directory]::CreateDirectory($dir) }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllBytes($Path, $enc.GetBytes($t))
}


$ErrorActionPreference="Stop"
$RepoRoot=(Resolve-Path -LiteralPath $RepoRoot).Path
$Scripts=Join-Path $RepoRoot "scripts"
$Eval=Join-Path $Scripts "evaluate_arbiter_v1.ps1"
# Windows PowerShell 5.1 when present, otherwise the PowerShell running this selftest.
$PSExe = $null
if($env:WINDIR){ $PSExe = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe" }
if(-not $PSExe -or -not (Test-Path -LiteralPath $PSExe -PathType Leaf)){ $PSExe = (Get-Process -Id $PID).Path }
$Lib=Join-Path $Scripts "_lib_arbiter_v1.ps1"
if(-not (Test-Path -LiteralPath $Eval -PathType Leaf)){ throw ("MISSING_EVAL: " + $Eval) }
if(-not (Test-Path -LiteralPath $Lib -PathType Leaf)){ throw ("MISSING_LIB: " + $Lib) }
. $Lib
$ExRoot = Join-Path (Join-Path $RepoRoot "examples") "watchtower_ingest"
$RulesDir = Join-Path $ExRoot "rules"
$OutDir   = Join-Path $ExRoot "out"
[void][System.IO.Directory]::CreateDirectory($ExRoot)
[void][System.IO.Directory]::CreateDirectory($RulesDir)
[void][System.IO.Directory]::CreateDirectory($OutDir)
$PolicySetPath = Join-Path $ExRoot "policyset.json"
$RuleFileRel   = "examples/watchtower_ingest/rules/ingest.rules.json"
$RuleFilePath  = Join-Path $RepoRoot $RuleFileRel
$ps = @{ schema="policy.policyset.v1"; engine="arbiter.v1"; engine_version="1.0.0"; evaluation=@{ mode="FIRST_MATCH_WINS" }; rule_files=@($RuleFileRel) }
[void](Arbiter-WriteCanonJsonFile -Path $PolicySetPath -Obj $ps)
$rf = @{ schema="policy.rule_file.v1"; rules=@( @{ schema="policy.rule.v1"; id="ALLOW_VALID_SIGNATURE"; effect="allow"; reasons=@("ALLOW_SIG_VALID"); when=@{ op="eq"; arg=@(@{ptr="trust.signature_valid"}, $true) } }, @{ schema="policy.rule.v1"; id="DENY_INVALID_SIGNATURE"; effect="deny"; reasons=@("DENY_SIG_INVALID"); when=@{ op="eq"; arg=@(@{ptr="trust.signature_valid"}, $false) } } ) }
[void](Arbiter-WriteCanonJsonFile -Path $RuleFilePath -Obj $rf)
$now=[DateTimeOffset]::UtcNow.ToString("o")
$pAllow=Join-Path $ExRoot "input_allow.json"; $pDeny=Join-Path $ExRoot "input_deny.json"
$inAllow=@{ schema="policy.input.v1"; env=@{ now=$now }; artifact=@{ kind="packet" }; trust=@{ signature_valid=$true } }
$inDeny =@{ schema="policy.input.v1"; env=@{ now=$now }; artifact=@{ kind="packet" }; trust=@{ signature_valid=$false } }
[void](Arbiter-WriteCanonJsonFile -Path $pAllow -Obj $inAllow)
[void](Arbiter-WriteCanonJsonFile -Path $pDeny  -Obj $inDeny)
$dec1=Join-Path $OutDir "decision_allow.json"; $dec2=Join-Path $OutDir "decision_deny.json"; $rcpt=Join-Path $OutDir "arbiter_receipts.ndjson"
# ARB_PATCH_SELFTEST_EVAL_CALL_REWRITE_V2
& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Eval -RepoRoot $RepoRoot -PolicySetPath $PolicySetPath -InputPath $pAllow -OutDecisionPath $dec1 -ReceiptPath $rcpt | Out-Host
# ARB_PATCH_SELFTEST_EVAL_CALL_REWRITE_V2
& $PSExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $Eval -RepoRoot $RepoRoot -PolicySetPath $PolicySetPath -InputPath $pDeny -OutDecisionPath $dec2 -ReceiptPath $rcpt | Out-Host
$o1 = (Get-Content -Raw -LiteralPath $dec1 -Encoding UTF8) | ConvertFrom-Json
$o2 = (Get-Content -Raw -LiteralPath $dec2 -Encoding UTF8) | ConvertFrom-Json
if([string]$o1.decision -ne "allow"){ throw ("SELFTEST_FAIL: expected allow decision, got " + [string]$o1.decision) }
if([string]$o2.decision -ne "deny"){ throw ("SELFTEST_FAIL: expected deny decision, got " + [string]$o2.decision) }
if([string]$o1.matched_rule_id -ne "ALLOW_VALID_SIGNATURE" -or [string]$o2.matched_rule_id -ne "DENY_INVALID_SIGNATURE"){ throw "SELFTEST_FAIL: wrong rule matched" }
if([string]$o1.policy_hash -ne "sha256:d734b68ad7a2351fd3322cf6212bb18747fd72ca47c9575557f351ca0e3de68d"){ throw ("SELFTEST_FAIL: policy_hash " + [string]$o1.policy_hash) }
Write-Host "SELFTEST_OK: allow+deny decisions produced; receipts appended." -ForegroundColor Green
Write-Host ("  repo : " + $RepoRoot) -ForegroundColor Gray
Write-Host ("  allow: " + $dec1) -ForegroundColor Gray
Write-Host ("  deny : " + $dec2) -ForegroundColor Gray
Write-Host ("  rcpt : " + $rcpt) -ForegroundColor Gray
