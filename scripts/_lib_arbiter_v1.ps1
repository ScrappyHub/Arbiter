param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Arbiter-NotImplemented([string]$What) {
  throw ("ARBITER_NOT_IMPLEMENTED: " + $What)
}
