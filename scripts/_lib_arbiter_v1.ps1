Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function WriteUtf8NoBomLf([string]$Path,[string]$Text){
  $t = ($Text -replace "`r`n","`n") -replace "`r","`n"
  if(-not $t.EndsWith("`n")){ $t += "`n" }
  $dir = Split-Path -Parent $Path
  if($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)){ [void][System.IO.Directory]::CreateDirectory($dir) }
  $enc = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllBytes($Path,$enc.GetBytes($t))
}

function Arbiter-Die([string]$Msg){ throw $Msg }
function Arbiter-Utf8NoBomBytes([string]$Text){ if($null -eq $Text){ $Text = "" }; $t = ($Text -replace "`r`n","`n") -replace "`r","`n"; return (New-Object System.Text.UTF8Encoding($false)).GetBytes($t) }
function Arbiter-Sha256HexBytes([byte[]]$Bytes){ if($null -eq $Bytes){ $Bytes = @() }; $sha = [System.Security.Cryptography.SHA256]::Create(); try{ $h = $sha.ComputeHash([byte[]]$Bytes) } finally { $sha.Dispose() }; $sb = New-Object System.Text.StringBuilder; for($i=0; $i -lt $h.Length; $i++){ [void]$sb.AppendFormat("{0:x2}",$h[$i]) }; return $sb.ToString() }
function Arbiter-Sha256HexFile([string]$Path){ if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ Arbiter-Die ("MISSING_FILE: " + $Path) }; $fs = New-Object System.IO.FileStream($Path,[System.IO.FileMode]::Open,[System.IO.FileAccess]::Read,[System.IO.FileShare]::Read); try{ $sha = [System.Security.Cryptography.SHA256]::Create(); try{ $h = $sha.ComputeHash($fs) } finally { $sha.Dispose() } } finally { $fs.Dispose() }; $sb = New-Object System.Text.StringBuilder; for($i=0; $i -lt $h.Length; $i++){ [void]$sb.AppendFormat("{0:x2}",$h[$i]) }; return $sb.ToString() }

function Arbiter-ConvertToHashtable($o){
  # Lists are returned with the unary comma so PowerShell never unrolls a one-item
  # array into a scalar (that unrolling changed policy hashes and broke rule matching).
  if($null -eq $o){ return $null }
  if($o -is [string]){ return $o }
  if($o -is [System.Collections.IDictionary]){
    $h = @{}
    foreach($k in $o.Keys){ $h[[string]$k] = Arbiter-ConvertToHashtable $o[$k] }
    return $h
  }
  if($o -is [pscustomobject]){
    $h = @{}
    foreach($p in $o.PSObject.Properties){ $h[[string]$p.Name] = Arbiter-ConvertToHashtable $p.Value }
    return $h
  }
  if($o -is [System.Collections.IEnumerable]){
    $list = New-Object System.Collections.Generic.List[object]
    foreach($it in $o){ [void]$list.Add((Arbiter-ConvertToHashtable $it)) }
    return ,($list.ToArray())
  }
  return $o
}
function Arbiter-FromJson([string]$Path){
  if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){ Arbiter-Die ("MISSING_JSON: " + $Path) }
  $txt = [System.IO.File]::ReadAllText($Path,(New-Object System.Text.UTF8Encoding($false)))
  # PowerShell 7's ConvertFrom-Json turns ISO date strings into DateTime; the canonical
  # bytes must keep the original string, so PowerShell 7 parses with Newtonsoft directly.
  # Windows PowerShell 5.1 keeps them as strings already.
  if($PSVersionTable.PSVersion.Major -ge 7){
    $reader = New-Object Newtonsoft.Json.JsonTextReader((New-Object System.IO.StringReader($txt)))
    $reader.DateParseHandling = [Newtonsoft.Json.DateParseHandling]::None
    $reader.FloatParseHandling = [Newtonsoft.Json.FloatParseHandling]::Decimal
    return [hashtable](Arbiter-JTokenToObject ([Newtonsoft.Json.Linq.JToken]::ReadFrom($reader)))
  }
  $obj = $txt | ConvertFrom-Json
  return [hashtable](Arbiter-ConvertToHashtable $obj)
}
function Arbiter-JTokenToObject($t){
  # Type checks use -is: PowerShell treats JObject as a dictionary, so $t.Type would be a key lookup.
  if($null -eq $t){ return $null }
  if($t -is [Newtonsoft.Json.Linq.JObject]){ $h = @{}; foreach($p in $t.Properties()){ $h[[string]$p.Name] = Arbiter-JTokenToObject $p.Value }; return $h }
  if($t -is [Newtonsoft.Json.Linq.JArray]){ $list = New-Object System.Collections.Generic.List[object]; foreach($x in $t){ [void]$list.Add((Arbiter-JTokenToObject $x)) }; return ,($list.ToArray()) }
  $v = $t.Value
  if($v -is [long] -and $v -ge [int]::MinValue -and $v -le [int]::MaxValue){ return [int]$v }
  return $v
}

function Arbiter-JsonEscape([string]$s){
  if($null -eq $s){ return "" }
  $sb = New-Object System.Text.StringBuilder
  for($i=0; $i -lt $s.Length; $i++){
    $c = [int][char]$s[$i]
    switch($c){
      34 { [void]$sb.Append('\"') }
      92 { [void]$sb.Append('\\') }
      8  { [void]$sb.Append('\b') }
      12 { [void]$sb.Append('\f') }
      10 { [void]$sb.Append('\n') }
      13 { [void]$sb.Append('\r') }
      9  { [void]$sb.Append('\t') }
      default { if($c -lt 32){ [void]$sb.Append('\u'); [void]$sb.Append(($c.ToString('x4'))) } else { [void]$sb.Append([char]$c) } }
    }
  }
  return $sb.ToString()
}

function Arbiter-WriteCanonJsonValue([System.Text.StringBuilder]$sb,$v){
  if($null -eq $v){ [void]$sb.Append('null'); return }
  if($v -is [bool]){ if($v){ [void]$sb.Append('true') } else { [void]$sb.Append('false') }; return }
  if($v -is [byte] -or $v -is [int16] -or $v -is [int32] -or $v -is [int64] -or $v -is [uint16] -or $v -is [uint32] -or $v -is [uint64] -or $v -is [single] -or $v -is [double] -or $v -is [decimal]){ $s = [string]::Format([System.Globalization.CultureInfo]::InvariantCulture,"{0}",$v); [void]$sb.Append($s); return }
  if($v -is [string]){ [void]$sb.Append('"'); [void]$sb.Append((Arbiter-JsonEscape $v)); [void]$sb.Append('"'); return }
  if($v -is [System.Collections.IDictionary]){
    [string[]]$keys = @($v.Keys | ForEach-Object { [string]$_ }); [Array]::Sort($keys,[StringComparer]::Ordinal)
    [void]$sb.Append('{')
    for($i=0; $i -lt $keys.Count; $i++){
      if($i -gt 0){ [void]$sb.Append(',') }
      $k = $keys[$i]
      [void]$sb.Append('"')
      [void]$sb.Append((Arbiter-JsonEscape $k))
      [void]$sb.Append('":')
      Arbiter-WriteCanonJsonValue $sb $v[$k]
    }
    [void]$sb.Append('}')
    return
  }
  if(($v -is [System.Collections.IEnumerable]) -and -not ($v -is [string])){
    $arr = @(@($v))
    [void]$sb.Append('[')
    for($i=0; $i -lt $arr.Count; $i++){ if($i -gt 0){ [void]$sb.Append(',') }; Arbiter-WriteCanonJsonValue $sb $arr[$i] }
    [void]$sb.Append(']')
    return
  }
  [void]$sb.Append('"'); [void]$sb.Append((Arbiter-JsonEscape ([string]$v))); [void]$sb.Append('"')
}
function Arbiter-ToCanonJson([hashtable]$Obj){ $sb = New-Object System.Text.StringBuilder; Arbiter-WriteCanonJsonValue $sb $Obj; return $sb.ToString() }
function Arbiter-CanonHashJsonObject([hashtable]$Obj,[switch]$WithTrailingLf){ $j = Arbiter-ToCanonJson $Obj; if($WithTrailingLf){ $j = $j + "`n" }; $bytes = Arbiter-Utf8NoBomBytes $j; return ("sha256:" + (Arbiter-Sha256HexBytes $bytes)) }
function Arbiter-WriteCanonJsonFile([string]$Path,[hashtable]$Obj){ $j = (Arbiter-ToCanonJson $Obj) + "`n"; WriteUtf8NoBomLf $Path $j; return ("sha256:" + (Arbiter-Sha256HexFile $Path)) }

function Arbiter-TryGetByPointer($Root,[string]$Ptr,[ref]$Found){
  $Found.Value = $false

  if($null -eq $Root){ return $null }
  if([string]::IsNullOrWhiteSpace($Ptr)){ return $null }

  if($Ptr.StartsWith("$.")){
    $Ptr = $Ptr.Substring(2)
  }

  $parts = $Ptr.Split('.')
  $current = Arbiter-ConvertToHashtable $Root

  foreach($p in $parts){
    if($null -eq $current){ return $null }
    if($current -is [System.Collections.IDictionary]){
      if(-not $current.ContainsKey($p)){ return $null }
      $current = $current[$p]
    } else {
      return $null
    }
  }

  $Found.Value = $true
  return $current
}
function Arbiter-ResolveOperand($Facts,$Operand,[ref]$Ok){
  # Operand forms: {"ptr":"a.b"} reads the input; {"const":v} or a bare literal is a value.
  $Ok.Value = $false
  if($null -eq $Operand){ $Ok.Value = $true; return $null }
  $op = Arbiter-ConvertToHashtable $Operand
  if($op -is [System.Collections.IDictionary]){
    if($op.ContainsKey("ptr")){
      $found = $false
      $val = Arbiter-TryGetByPointer $Facts ([string]$op["ptr"]) ([ref]$found)
      if($found){ $Ok.Value = $true; return ,$val }
      return $null
    }
    if($op.ContainsKey("const")){ $Ok.Value = $true; return ,$op["const"] }
  }
  $Ok.Value = $true
  return ,$Operand
}
function Arbiter-ValuesEqual($a,$b){
  if($null -eq $a -or $null -eq $b){ return ($null -eq $a -and $null -eq $b) }
  if(($a -is [bool]) -or ($b -is [bool])){ return (($a -is [bool]) -and ($b -is [bool]) -and ($a -eq $b)) }
  return ((Arbiter-ToCanonJson @{ v = $a }) -ceq (Arbiter-ToCanonJson @{ v = $b }))
}
function Arbiter-EvalCondition($Facts,$Cond){
  if($null -eq $Cond){ return $false }
  $c = Arbiter-ConvertToHashtable $Cond
  if(-not ($c -is [System.Collections.IDictionary])){ return $false }
  $op = [string]$c["op"]
  switch($op){
    "eq" {
      $a = @($c["arg"])
      if($a.Count -ne 2){ return $false }
      $ok1 = $false; $ok2 = $false
      $v1 = Arbiter-ResolveOperand $Facts $a[0] ([ref]$ok1)
      $v2 = Arbiter-ResolveOperand $Facts $a[1] ([ref]$ok2)
      if(-not ($ok1 -and $ok2)){ return $false }
      return (Arbiter-ValuesEqual $v1 $v2)
    }
    "not" { return (-not (Arbiter-EvalCondition $Facts $c["arg"])) }
    default { return $false }
  }
}

function Arbiter-Evaluate([string]$RepoRoot,[string]$PolicySetPath,[string]$InputPath){
  $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
  $ps = Arbiter-FromJson $PolicySetPath
  $in = Arbiter-FromJson $InputPath
  $rfRel = [string](@(@($ps["rule_files"]))[0])
  $rf = Arbiter-FromJson (Join-Path $RepoRoot $rfRel)
  $rules = @(@($rf["rules"]))
  $matched = $null
  foreach($r in $rules){
    $rule = [hashtable](Arbiter-ConvertToHashtable $r)
    $when = $null
    if($rule.ContainsKey("when")){ $when = $rule["when"] }
    if(Arbiter-EvalCondition $in $when){
      $matched = $rule
      break
    }
  }
  if($null -ne $matched){
    $decision = [string]$matched["effect"]
    $reasons = @(@($matched["reasons"]))
    $matchedId = [string]$matched["id"]
  } else {
    $decision = "deny"
    $reasons = @("DENY_NO_RULE_MATCHED")
    $matchedId = $null
  }
  $env = [hashtable](Arbiter-ConvertToHashtable $in["env"])
  $input_hash = Arbiter-CanonHashJsonObject $in -WithTrailingLf
  $policy_hash = Arbiter-CanonHashJsonObject $ps -WithTrailingLf
  $dec = @{ schema="policy.decision.v1"; engine="arbiter.v1"; engine_version="1.0.0"; evaluated_at=[string]$env["now"]; decision=$decision; matched_rule_id=$matchedId; reasons=@(@($reasons)); obligations=@(); policy_hash=$policy_hash; input_hash=$input_hash; decision_hash="" }
  $tmp = @{}
  foreach($k in $dec.Keys){ if($k -ne "decision_hash"){ $tmp[$k] = $dec[$k] } }
  $tmp["decision_hash"] = ""
  $dh = Arbiter-CanonHashJsonObject $tmp -WithTrailingLf
  $dec["decision_hash"] = $dh
  return $dec
}

function Arbiter-AppendReceipt([string]$ReceiptPath,[hashtable]$LineObj){
  $j = (Arbiter-ToCanonJson $LineObj) + "`n"
  $j = ($j -replace "`r`n","`n") -replace "`r","`n"
  $enc = New-Object System.Text.UTF8Encoding($false)
  $bytes = $enc.GetBytes($j)
  $dir = Split-Path -Parent $ReceiptPath
  if($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)){ [void][System.IO.Directory]::CreateDirectory($dir) }
  $fs = New-Object System.IO.FileStream($ReceiptPath,[System.IO.FileMode]::Append,[System.IO.FileAccess]::Write,[System.IO.FileShare]::Read)
  try{ $fs.Write($bytes,0,$bytes.Length) } finally { $fs.Dispose() }
}
