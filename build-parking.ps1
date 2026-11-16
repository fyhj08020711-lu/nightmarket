#requires -Version 5.1
<#
  產生 parking-tdx.js：交通部 TDX 的停車場資料（含收費說明），只保留各夜市 700 公尺內的停車場。
  使用方式（在本資料夾的 PowerShell 內）：
    $env:TDX_ID="你的Client Id"; $env:TDX_SECRET="你的Client Secret"
    .\build-parking.ps1
  之後重新整理頁面即可。資料是快照，想更新就再跑一次。
  帳號申請：https://tdx.transportdata.tw/ （免費，註冊後到「會員中心 > 資料服務 > API金鑰」取得）
#>
$ErrorActionPreference = 'Stop'
if (-not $env:TDX_ID -or -not $env:TDX_SECRET) { Write-Error '請先設定環境變數 TDX_ID 與 TDX_SECRET'; exit 1 }
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$html = [System.IO.File]::ReadAllText("$dir\index.html", [Text.Encoding]::UTF8)

# 夜市（排除已有臺北市政府資料的臺北市）
$mk = @()
foreach ($m in [regex]::Matches($html, '\["([^"]+)","([^"]+)","[^"]+",([\d.]+),([\d.]+)')) {
  if ($m.Groups[2].Value -ne '臺北市') { $mk += ,@($m.Groups[2].Value, [double]$m.Groups[3].Value, [double]$m.Groups[4].Value) }
}
$code = @{ '基隆市'='Keelung'; '新北市'='NewTaipei'; '桃園市'='Taoyuan'; '新竹市'='Hsinchu'; '新竹縣'='HsinchuCounty'; '苗栗縣'='MiaoliCounty';
  '臺中市'='Taichung'; '彰化縣'='ChanghuaCounty'; '南投縣'='NantouCounty'; '雲林縣'='YunlinCounty'; '嘉義市'='Chiayi'; '嘉義縣'='ChiayiCounty';
  '臺南市'='Tainan'; '高雄市'='Kaohsiung'; '屏東縣'='PingtungCounty'; '宜蘭縣'='YilanCounty'; '花蓮縣'='HualienCounty'; '臺東縣'='TaitungCounty' }

$tok = (Invoke-RestMethod -Method Post -Uri 'https://tdx.transportdata.tw/auth/realms/TDXConnect/protocol/openid-connect/token' `
  -ContentType 'application/x-www-form-urlencoded' `
  -Body @{ grant_type='client_credentials'; client_id=$env:TDX_ID; client_secret=$env:TDX_SECRET }).access_token
$hdr = @{ Authorization = "Bearer $tok" }

function Hav($a1,$b1,$a2,$b2){$r=[Math]::PI/180;$dl=($a2-$a1)*$r;$dg=($b2-$b1)*$r;$x=[Math]::Pow([Math]::Sin($dl/2),2)+[Math]::Cos($a1*$r)*[Math]::Cos($a2*$r)*[Math]::Pow([Math]::Sin($dg/2),2);2*6371000*[Math]::Asin([Math]::Sqrt($x))}

$out = New-Object System.Collections.ArrayList; $seen = @{}
foreach ($city in ($mk | ForEach-Object { $_[0] } | Select-Object -Unique)) {
  $c = $code[$city]; if (-not $c) { continue }
  try {
    $r = Invoke-RestMethod -Headers $hdr -Uri "https://tdx.transportdata.tw/api/basic/v1/Parking/OffStreet/CarPark/City/$c`?`$format=JSON" -TimeoutSec 120
  } catch { Write-Host "$city($c)：無資料或失敗 - $($_.Exception.Message)"; continue }
  $n = 0
  foreach ($p in $r.CarParks) {
    $la = [double]$p.CarParkPosition.PositionLat; $lo = [double]$p.CarParkPosition.PositionLon
    if (-not $la -or -not $lo) { continue }
    $near = $false
    foreach ($m in $mk) { if ($m[0] -eq $city -and (Hav $la $lo $m[1] $m[2]) -le 700) { $near = $true; break } }
    if (-not $near -or $seen[$p.CarParkID]) { continue }
    $seen[$p.CarParkID] = 1; $n++
    $fare = $p.FareDescription; if (-not $fare) { $fare = '' }
    [void]$out.Add([pscustomobject]@{ n=$p.CarParkName.Zh_tw; la=[Math]::Round($la,5); lo=[Math]::Round($lo,5); ad=[string]$p.Address; pr=$fare; st=''; c=0 })
  }
  Write-Host "$city：$n 個停車場"
}
$json = ($out | ConvertTo-Json -Compress); if ($out.Count -eq 1) { $json = "[$json]" }; if ($out.Count -eq 0) { $json = '[]' }
$upd = (Get-Date).ToString('yyyy/MM/dd')
$js = "// 交通部 TDX 停車場資料快照（$upd）；僅保留各夜市 700 公尺內者`nconst PK2=$json;`n"
[System.IO.File]::WriteAllText("$dir\parking-tdx.js", $js, (New-Object Text.UTF8Encoding($false)))
Write-Host "完成：共 $($out.Count) 個停車場 -> parking-tdx.js"
