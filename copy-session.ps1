param(
  [string]$SessionId,
  [string]$TargetDir,
  [string]$DbPath = "$env:USERPROFILE/.local/share/opencode/opencode.db"
)

if (-not $SessionId -or -not $TargetDir) { Write-Host "Usage: .\copy-session.ps1 <session_id> <target_dir>"; exit 1 }

$TargetDir = $TargetDir.TrimEnd('\').TrimEnd('/')
if ($TargetDir -match '^[a-zA-Z]:$') { $TargetDir += '/' }
if (-not (Test-Path $TargetDir)) { Write-Error "Dir not found: $TargetDir"; exit 1 }

$newSid = "ses_" + [System.Guid]::NewGuid().ToString('N').Substring(0, 26)
$dir = $TargetDir -replace '\\', '/'
$rel = $dir -replace '^[a-zA-Z]:/', ''
$nowMs = [System.DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()

Write-Host "Copy: $SessionId -> $newSid [$dir]"

$oldMsgIds = @(sqlite3 $DbPath "SELECT id FROM message WHERE session_id='$SessionId' ORDER BY time_created, id")
$oldPrtIds = @(sqlite3 $DbPath "SELECT id FROM part WHERE session_id='$SessionId' ORDER BY id")
Write-Host "  Msgs: $($oldMsgIds.Count), Parts: $($oldPrtIds.Count)"

$idMap = @{}
foreach ($id in $oldMsgIds) {
  $suffix = $id.Substring(4)
  $n = 'msg_' + [System.Guid]::NewGuid().ToString('N').Substring(0, 24)
  $idMap[$id] = $n
  $idMap['sg_' + $suffix] = 'sg_' + $n.Substring(4)
}
foreach ($id in $oldPrtIds) {
  $n = 'prt_' + [System.Guid]::NewGuid().ToString('N').Substring(0, 24)
  $idMap[$id] = $n
}

$idRegex = [regex]'(msg_|sg_|prt_)[a-zA-Z0-9]+'
$perm = '[{"permission":"question","pattern":"*","action":"deny"},{"permission":"plan_enter","pattern":"*","action":"deny"},{"permission":"plan_exit","pattern":"*","action":"deny"}]'

# Helper: execute sqlite3 query, return lines with UTF-8 encoding
function Sqlite3-Query($db, $sql, $separator) {
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = "sqlite3.exe"
  if ($separator) { $args = "-separator `"`t`" `"$db`" `"$sql`"" } else { $args = "`"$db`" `"$sql`"" }
  $psi.Arguments = $args
  $psi.RedirectStandardOutput = $true
  $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
  $psi.UseShellExecute = $false
  $p = [System.Diagnostics.Process]::Start($psi)
  $reader = $p.StandardOutput
  $line = $reader.ReadLine()
  while ($line -ne $null) {
    $line
    $line = $reader.ReadLine()
  }
  $p.WaitForExit()
}

# Write session row
Write-Host "  Creating session..."
$sql = "INSERT INTO session(id,project_id,directory,path,title,slug,version,agent,model,time_created,time_updated,cost,tokens_input,tokens_output,tokens_reasoning,tokens_cache_read,tokens_cache_write,metadata,summary_additions,summary_deletions,summary_files,permission) SELECT '$newSid','global','$dir','$rel',title,slug,version,agent,model,time_created,$nowMs,cost,tokens_input,tokens_output,tokens_reasoning,tokens_cache_read,tokens_cache_write,metadata,0,0,0,'$perm' FROM session WHERE id='$SessionId';"
$sql | Out-File -Encoding UTF8 -FilePath "$env:TEMP\oc_sql.txt"
& cmd /c "sqlite3.exe `"$DbPath`" < `"$env:TEMP\oc_sql.txt`" 2>&1"

# Helper: process sqlite3 output with UTF-8, regex-replace IDs, write INSERTs to file
function Process-Table($table, $columns, $splitCount) {
  $colList = $columns -join ", "
  Write-Host "  Copying $table..."
  $tot = 0; $cnt = 0
  $sw = New-Object System.IO.StreamWriter("$env:TEMP\oc_sql.txt", $false, [System.Text.Encoding]::UTF8)
  $sw.WriteLine("BEGIN;")
  $regex = $idRegex
  $map = $idMap
  $sid = $newSid
  $lines = Sqlite3-Query $DbPath "SELECT $colList FROM $table WHERE session_id='$SessionId' ORDER BY time_created, id" $true
  foreach ($line in $lines) {
    $tot++
    $t = $line -split "`t"
    if ($t.Count -lt $splitCount) { continue }
    # Build INSERT based on column list
    if ($table -eq "message") {
      $oid = $t[0]; $tc = $t[1]; $tu = $t[2]; $d = $t[3]
      $d = $regex.Replace($d, { param($x) if ($map.ContainsKey($x.Value)) { $map[$x.Value] } else { $x.Value } })
      $d = $d -replace "'", "''"
      $sw.WriteLine("INSERT INTO message VALUES('$($map[$oid])','$sid',$tc,$tu,'$d');")
    } else {
      $oid = $t[0]; $omid = $t[1]; $tc = $t[2]; $tu = $t[3]; $d = $t[4]
      $d = $regex.Replace($d, { param($x) if ($map.ContainsKey($x.Value)) { $map[$x.Value] } else { $x.Value } })
      $d = $d -replace "'", "''"
      $sw.WriteLine("INSERT INTO part VALUES('$($map[$oid])','$($map[$omid])','$sid',$tc,$tu,'$d');")
    }
    $cnt++
    if ($cnt % 1000 -eq 0) { Write-Host "    $cnt..." }
  }
  $sw.WriteLine("COMMIT;")
  $sw.Close()
  # Execute with cmd redirect (preserves UTF-8)
  $err = cmd /c "sqlite3.exe `"$DbPath`" < `"$env:TEMP\oc_sql.txt`" 2>&1"
  if ($LASTEXITCODE -ne 0) { throw "$table error: $err" }
  Write-Host "    $cnt done"
}

Process-Table "message" @("id", "time_created", "time_updated", "data") 4
Process-Table "part" @("id", "message_id", "time_created", "time_updated", "data") 5

# session_message rows
Write-Host "  Creating session messages..."
$sm1 = 'msg_' + [System.Guid]::NewGuid().ToString('N').Substring(0, 24)
$sm2 = 'msg_' + [System.Guid]::NewGuid().ToString('N').Substring(0, 24)
$ad = '{"time":{"created":' + $nowMs + '},"agent":"build"}'
$md = '{"time":{"created":' + $nowMs + '},"model":{"id":"deepseek-v4-flash-free","providerID":"opencode","variant":"default"}}'
$sql = "INSERT INTO session_message VALUES('$sm1','$newSid','agent-switched',$nowMs,$nowMs,'$ad',1);INSERT INTO session_message VALUES('$sm2','$newSid','model-switched',$nowMs,$nowMs,'$md',2);"
$sql | Out-File -Encoding UTF8 -FilePath "$env:TEMP\oc_sql.txt"
$err = cmd /c "sqlite3.exe `"$DbPath`" < `"$env:TEMP\oc_sql.txt`" 2>&1"
if ($LASTEXITCODE -ne 0) { Write-Error "Session message error: $err"; exit 1 }

Remove-Item "$env:TEMP\oc_sql.txt" -ErrorAction SilentlyContinue
Write-Host "Done: $newSid"
