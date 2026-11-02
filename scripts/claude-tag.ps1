# Dot-source from your $PROFILE (. path\to\claude-tag.ps1). Adds `cct`, which starts Claude Code with tags for the dashboards.
#
#   cct myapp fix-login 2          project task run
#   cct myapp fix-login            run defaults to 1
#   cct                            project = git repo or folder name, task = untagged, run = 1
#   cct myapp fix-login 2 -- --resume    anything after -- goes to claude
#
# Plain `claude` is untouched. Tag values keep only A-Z a-z 0-9 . _ -
# Untested. In particular, check that `--` reaches the function as an argument on your PowerShell version.
function cct {
  $clean = { param($s) $s -replace '[^A-Za-z0-9._-]', '-' }
  $i = 0
  $tags = @()
  while ($tags.Count -lt 3 -and $i -lt $args.Count -and "$($args[$i])" -notlike '-*') { $tags += $args[$i]; $i++ }
  if ($i -lt $args.Count -and "$($args[$i])" -eq '--') { $i++ }
  $rest = if ($i -lt $args.Count) { @($args[$i..($args.Count - 1)]) } else { @() }
  $root = try { git rev-parse --show-toplevel 2>$null } catch { $null }
  $p = if ($tags.Count -ge 1) { $tags[0] } elseif ($root) { Split-Path $root -Leaf } else { Split-Path (Get-Location) -Leaf }
  $t = if ($tags.Count -ge 2) { $tags[1] } else { 'untagged' }
  $r = if ($tags.Count -ge 3) { $tags[2] } else { '1' }
  $old = $env:OTEL_RESOURCE_ATTRIBUTES
  try {
    $env:OTEL_RESOURCE_ATTRIBUTES = "project=$(& $clean $p),task=$(& $clean $t),run=$(& $clean $r)"
    & (Get-Command claude -CommandType Application | Select-Object -First 1).Source @rest
  } finally {
    $env:OTEL_RESOURCE_ATTRIBUTES = $old   # restore, so a later plain `claude` is not tagged
  }
}
