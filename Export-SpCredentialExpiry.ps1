<# 
.SYNOPSIS
  すべての Service Principal の資格情報（Password/Certificate）の期限情報を収集しCSV出力します。
  - Service Principal 側の資格情報（Managed Identity 等で生成されるもの）も収集
  - 対応する Application 側の資格情報（通常のクライアントシークレット/証明書）も収集

.PREREQ
  az login --tenant <your-tenant-id>
  ※テナント内アプリ一覧の読み取り権限（Directory.Read.All など）が必要

.EXAMPLE
  .\Export-SpCredentialExpiry.ps1 -OutputPath .\sp-credentials.csv
#>

param(
  [string]$OutputPath = ".\sp-credentials.csv"
)

# ------------- 共通: Graph 呼び出し準備 -------------
Write-Host "Getting Microsoft Graph access token via Azure CLI..." -ForegroundColor Cyan
$accessToken = (az account get-access-token --resource-type ms-graph --query accessToken -o tsv) 2>$null
if ([string]::IsNullOrWhiteSpace($accessToken)) {
  throw "Failed to acquire Graph access token. Please run: az login --tenant <your-tenant-id>"
}
$Headers = @{ Authorization = "Bearer $accessToken" }
$GraphBase = "https://graph.microsoft.com/v1.0"

function Invoke-GraphGetAll {
  param(
    [Parameter(Mandatory=$true)][string]$Url
  )
  $all = @()
  $next = $Url
  while ($next) {
    $resp = Invoke-RestMethod -Method GET -Uri $next -Headers $Headers -ErrorAction Stop
    if ($resp.value) { $all += $resp.value }
    $next = $resp.'@odata.nextLink'
  }
  return $all
}

# ------------- 取得: Service Principals -------------
Write-Host "Fetching service principals..." -ForegroundColor Cyan
# SP自身に資格情報が付くケースもあるため passwordCredentials/keyCredentials も取得
$spUrl = "$GraphBase/servicePrincipals?`$select=id,appId,displayName,createdDateTime,passwordCredentials,keyCredentials&`$top=999"
$servicePrincipals = Invoke-GraphGetAll -Url $spUrl

# ------------- 取得: Applications -------------
Write-Host "Fetching applications..." -ForegroundColor Cyan
# Application 側の資格情報も取得
$appUrl = "$GraphBase/applications?`$select=id,appId,displayName,passwordCredentials,keyCredentials&`$top=999"
$applications = Invoke-GraphGetAll -Url $appUrl

# ------------- インデックス化（appId -> application）-------------
$appByAppId = @{}
foreach ($app in $applications) {
  if ($app.appId -and -not $appByAppId.ContainsKey($app.appId)) {
    $appByAppId[$app.appId] = $app
  }
}

# ------------- 整形: 出力行の作成 -------------
$now = (Get-Date).ToUniversalTime()
$rows = New-Object System.Collections.Generic.List[object]

foreach ($sp in $servicePrincipals) {
  $spCreated = $null
  if ($sp.createdDateTime) {
    $spCreated = [datetime]::Parse($sp.createdDateTime).ToUniversalTime()
  }

  # 1) SPエンティティ側の資格情報（Managed Identity 等）
  $spPwCreds  = @($sp.passwordCredentials)  | Where-Object { $_ -ne $null }
  $spKeyCreds = @($sp.keyCredentials)       | Where-Object { $_ -ne $null }

  foreach ($c in $spPwCreds) {
    $start = if ($c.startDateTime) { [datetime]::Parse($c.startDateTime).ToUniversalTime() } else { $null }
    $end   = if ($c.endDateTime)   { [datetime]::Parse($c.endDateTime).ToUniversalTime() } else { $null }
    $days  = if ($end) { [math]::Floor(($end - $now).TotalDays) } else { $null }
    $rows.Add([pscustomobject]@{
      Source                        = "ServicePrincipal"
      ServicePrincipalDisplayName   = $sp.displayName
      ServicePrincipalObjectId      = $sp.id
      AppId                         = $sp.appId
      SPCreatedDateTimeUtc          = $spCreated
      CredentialType                = "Password"
      CredentialDisplayName         = $c.displayName
      KeyId                         = $c.keyId
      StartDateTimeUtc              = $start
      EndDateTimeUtc                = $end
      DaysToExpire                  = $days
      IsExpired                     = if ($end) { $end -lt $now } else { $null }
    })
  }
  foreach ($c in $spKeyCreds) {
    $start = if ($c.startDateTime) { [datetime]::Parse($c.startDateTime).ToUniversalTime() } else { $null }
    $end   = if ($c.endDateTime)   { [datetime]::Parse($c.endDateTime).ToUniversalTime() } else { $null }
    $days  = if ($end) { [math]::Floor(($end - $now).TotalDays) } else { $null }
    $rows.Add([pscustomobject]@{
      Source                        = "ServicePrincipal"
      ServicePrincipalDisplayName   = $sp.displayName
      ServicePrincipalObjectId      = $sp.id
      AppId                         = $sp.appId
      SPCreatedDateTimeUtc          = $spCreated
      CredentialType                = "Certificate"
      CredentialDisplayName         = $c.displayName
      KeyId                         = $c.keyId
      StartDateTimeUtc              = $start
      EndDateTimeUtc                = $end
      DaysToExpire                  = $days
      IsExpired                     = if ($end) { $end -lt $now } else { $null }
    })
  }

  # 2) Application エンティティ側の資格情報（一般的なクライアントシークレット/証明書）
  if ($sp.appId -and $appByAppId.ContainsKey($sp.appId)) {
    $app = $appByAppId[$sp.appId]
    $appPwCreds  = @($app.passwordCredentials) | Where-Object { $_ -ne $null }
    $appKeyCreds = @($app.keyCredentials)      | Where-Object { $_ -ne $null }

    foreach ($c in $appPwCreds) {
      $start = if ($c.startDateTime) { [datetime]::Parse($c.startDateTime).ToUniversalTime() } else { $null }
      $end   = if ($c.endDateTime)   { [datetime]::Parse($c.endDateTime).ToUniversalTime() } else { $null }
      $days  = if ($end) { [math]::Floor(($end - $now).TotalDays) } else { $null }
      $rows.Add([pscustomobject]@{
        Source                        = "Application"
        ServicePrincipalDisplayName   = $sp.displayName
        ServicePrincipalObjectId      = $sp.id
        AppId                         = $sp.appId
        ApplicationObjectId           = $app.id
        SPCreatedDateTimeUtc          = $spCreated
        CredentialType                = "Password"
        CredentialDisplayName         = $c.displayName
        KeyId                         = $c.keyId
        StartDateTimeUtc              = $start
        EndDateTimeUtc                = $end
        DaysToExpire                  = $days
        IsExpired                     = if ($end) { $end -lt $now } else { $null }
      })
    }
    foreach ($c in $appKeyCreds) {
      $start = if ($c.startDateTime) { [datetime]::Parse($c.startDateTime).ToUniversalTime() } else { $null }
      $end   = if ($c.endDateTime)   { [datetime]::Parse($c.endDateTime).ToUniversalTime() } else { $null }
      $days  = if ($end) { [math]::Floor(($end - $now).TotalDays) } else { $null }
      $rows.Add([pscustomobject]@{
        Source                        = "Application"
        ServicePrincipalDisplayName   = $sp.displayName
        ServicePrincipalObjectId      = $sp.id
        AppId                         = $sp.appId
        ApplicationObjectId           = $app.id
        SPCreatedDateTimeUtc          = $spCreated
        CredentialType                = "Certificate"
        CredentialDisplayName         = $c.displayName
        KeyId                         = $c.keyId
        StartDateTimeUtc              = $start
        EndDateTimeUtc                = $end
        DaysToExpire                  = $days
        IsExpired                     = if ($end) { $end -lt $now } else { $null }
      })
    }
  }
}

if ($rows.Count -eq 0) {
  Write-Warning "No credentials found on service principals or applications."
  return
}

Write-Host "Found $($rows.Count) credential entries" -ForegroundColor Yellow

# ------------- CSV 出力 -------------
$sortedRows = $rows | Sort-Object -Property EndDateTimeUtc, ServicePrincipalDisplayName

# UTF-8（BOMなし）でCSVファイルを作成
$csvContent = $sortedRows | ConvertTo-Csv -NoTypeInformation
$csvString = $csvContent -join "`r`n"
[System.IO.File]::WriteAllText($OutputPath, $csvString, [System.Text.UTF8Encoding]::new($false))

Write-Host "Done. Exported $($sortedRows.Count) credential entries to $OutputPath (UTF-8 encoding)" -ForegroundColor Green
