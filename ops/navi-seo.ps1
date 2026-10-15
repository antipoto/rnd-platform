# navi 페이지 SEO 일괄 적용 스크립트 (labwith.kr/navi/)
# 사용법: 서버 PowerShell에 이 파일 내용을 그대로 붙여 넣거나
#         powershell -ExecutionPolicy Bypass -File navi-seo.ps1
# 순서: 진단 → 백업 → 대상이 정확히 1곳일 때만 수정 → 실사이트 확인 → 실패 시 자동 복구

$R      = 'D:\dify\docker\static\labwith\site'
$URL    = 'https://www.labwith.kr/navi/'
$TITLE  = '2026 정부지원사업 일정과 마감일 한눈에 보기 | 기술사업화 랩 위드㈜'
$DESC   = '2026년 정부지원사업(R&D·창업·사업화) 공고 일정과 마감일을 분야별로 한눈에 확인하세요. 기술사업화 랩 위드㈜의 정부지원사업 내비게이터입니다.'
$Utf8   = New-Object Text.UTF8Encoding $false
$Stamp  = Get-Date -Format 'yyyyMMdd_HHmmss'
$BakDir = Join-Path $R "_backup_navi_seo_$Stamp"
$Done   = @()

function Read-U($p){ [IO.File]::ReadAllText($p,[Text.Encoding]::UTF8) }
function Write-U($p,$t){ [IO.File]::WriteAllText($p,$t,$Utf8) }
function Backup($p){ if(Test-Path $p){ Copy-Item $p (Join-Path $BakDir ((Split-Path $p -Leaf) + '.bak')) -Force; $script:Done += $p } }
function Esc($s){ [Net.WebUtility]::HtmlEncode($s) }

$f = Join-Path $R 'navi\index.html'
if(-not (Test-Path $f)){ Write-Host "[중단] $f 없음" -ForegroundColor Red; return }
New-Item -ItemType Directory -Path $BakDir -Force | Out-Null

# ---------- 1. index.html ----------
Backup $f
$t = Read-U $f; $orig = $t
Write-Host '=== [진단] 현재 head ==='
([regex]::Matches($t,'<title>[\s\S]*?</title>|<meta[^>]+(name|property)="(description|robots|og:[a-z]+)"[^>]*>|<link[^>]+rel="canonical"[^>]*>')) | ForEach-Object { Write-Host ('  ' + $_.Value) }
Write-Host '=== [진단] h1/h2 ==='
[regex]::Matches($t,'<h[12][^>]*>([\s\S]*?)</h[12]>') | Select-Object -First 10 | ForEach-Object { Write-Host ('  ' + ($_.Value.Substring(0,3)) + ' ' + ($_.Groups[1].Value -replace '<[^>]+>','').Trim()) }

$m = [regex]::Matches($t,'<title>[\s\S]*?</title>')
if($m.Count -eq 1){ $t = $t.Replace($m[0].Value,"<title>$(Esc $TITLE)</title>"); Write-Host '[적용] title 교체' -ForegroundColor Green }
else { Write-Host "[건너뜀] title $($m.Count)곳" -ForegroundColor Yellow }

$add = @()
$m = [regex]::Matches($t,'<meta[^>]+name="description"[^>]*>')
if($m.Count -eq 1){ $t = $t.Replace($m[0].Value,"<meta name=`"description`" content=`"$(Esc $DESC)`">"); Write-Host '[적용] description 교체' -ForegroundColor Green }
elseif($m.Count -eq 0){ $add += "<meta name=`"description`" content=`"$(Esc $DESC)`">" }
else { Write-Host "[건너뜀] description $($m.Count)곳" -ForegroundColor Yellow }

if($t -notmatch 'rel="canonical"'){ $add += "<link rel=`"canonical`" href=`"$URL`">" }
foreach($p in @(@('og:title',$TITLE),@('og:description',$DESC),@('og:url',$URL),@('og:type','website'))){
  $m = [regex]::Matches($t,"<meta[^>]+property=`"$($p[0])`"[^>]*>")
  if($m.Count -eq 1){ $t = $t.Replace($m[0].Value,"<meta property=`"$($p[0])`" content=`"$(Esc $p[1])`">") }
  elseif($m.Count -eq 0){ $add += "<meta property=`"$($p[0])`" content=`"$(Esc $p[1])`">" }
}
if($t -notmatch 'id="navi-jsonld"'){
  $ld = [ordered]@{
    '@context'='https://schema.org'; '@type'='CollectionPage'; name=$TITLE; description=$DESC; url=$URL; inLanguage='ko-KR'
    about=@('정부지원사업','R&D 과제 공고','창업지원사업','사업화 지원사업')
    publisher=[ordered]@{ '@type'='Organization'; name='기술사업화 랩 위드㈜'; url='https://www.labwith.kr/' }
    breadcrumb=[ordered]@{ '@type'='BreadcrumbList'; itemListElement=@(
      [ordered]@{ '@type'='ListItem'; position=1; name='홈'; item='https://www.labwith.kr/' },
      [ordered]@{ '@type'='ListItem'; position=2; name='정부지원사업 일정'; item=$URL }) }
  } | ConvertTo-Json -Depth 6 -Compress
  $add += "<script type=`"application/ld+json`" id=`"navi-jsonld`">$ld</script>"
}
if($add.Count -gt 0){
  $m = [regex]::Matches($t,'</head>')
  if($m.Count -eq 1){ $t = $t.Replace('</head>', ($add -join "`n") + "`n</head>"); Write-Host "[적용] head에 $($add.Count)개 추가 (description/canonical/og/JSON-LD)" -ForegroundColor Green }
  else { Write-Host "[건너뜀] </head> $($m.Count)곳" -ForegroundColor Yellow }
}
if($t -ne $orig){ Write-U $f $t }

# ---------- 2. robots.txt ----------
$rb = Join-Path $R 'robots.txt'
if(Test-Path $rb){
  $r0 = Read-U $rb
  $r1 = ($r0 -split "`r?`n" | Where-Object { $_ -notmatch '^\s*Disallow:\s*/navi' }) -join "`n"
  if($r1 -notmatch '(?im)^\s*Sitemap:'){ $r1 = $r1.TrimEnd() + "`nSitemap: https://www.labwith.kr/sitemap.xml`n" }
  if($r1 -ne $r0){ Backup $rb; Write-U $rb $r1; Write-Host '[적용] robots.txt 수정' -ForegroundColor Green } else { Write-Host '[유지] robots.txt 변경 불필요' }
  if($r1 -match '(?im)^\s*Disallow:\s*/\s*$'){ Write-Host '[경고] robots.txt에 "Disallow: /" (전체 차단) 있음 - 확인 필요' -ForegroundColor Red }
}

# ---------- 3. sitemap.xml ----------
$sm = Join-Path $R 'sitemap.xml'
if(Test-Path $sm){
  $s0 = Read-U $sm
  if($s0 -match '/navi/'){ Write-Host '[유지] sitemap에 navi 이미 있음' }
  elseif(([regex]::Matches($s0,'</urlset>')).Count -eq 1){
    $u = "  <url><loc>$URL</loc><lastmod>$(Get-Date -Format 'yyyy-MM-dd')</lastmod><changefreq>daily</changefreq><priority>0.8</priority></url>`n</urlset>"
    Backup $sm; Write-U $sm ($s0.Replace('</urlset>',$u)); Write-Host '[적용] sitemap.xml에 navi 추가' -ForegroundColor Green
  } else { Write-Host '[건너뜀] sitemap.xml 형식이 urlset 1개가 아님 (sitemap index일 수 있음)' -ForegroundColor Yellow }
}

# ---------- 4. 실사이트 확인 → 실패 시 복구 ----------
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ok = $true
try{
  $res = Invoke-WebRequest "$URL`?v=$Stamp" -UseBasicParsing -TimeoutSec 20
  $body = [Text.Encoding]::UTF8.GetString($res.RawContentStream.ToArray())
  if($res.StatusCode -ne 200 -or $body -notmatch 'navi-jsonld'){ $ok = $false }
  Write-Host "=== [확인] $URL -> $($res.StatusCode), 새 head 반영: $($body -match 'navi-jsonld')"
} catch { $ok = $false; Write-Host "[확인 실패] $($_.Exception.Message)" -ForegroundColor Red }

if(-not $ok){
  foreach($p in $Done){ Copy-Item (Join-Path $BakDir ((Split-Path $p -Leaf) + '.bak')) $p -Force }
  Write-Host "[복구 완료] 원래 파일로 되돌림. 백업: $BakDir" -ForegroundColor Red
} else {
  Write-Host "[완료] 백업 위치: $BakDir" -ForegroundColor Green
  Write-Host '다음: Search Console > URL 검사 > https://www.labwith.kr/navi/ > 색인 생성 요청'
}
