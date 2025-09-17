# Export-Azure-SpCredentialExpiry

Azure環境内のすべてのService Principalの資格情報（パスワード/証明書）の有効期限を収集し、CSV形式でエクスポートするPowerShellスクリプトです。

## 概要

このスクリプトは、Azure ADテナント内のすべてのService Principalの資格情報を調査し、以下の情報をCSVファイルに出力します：

- Service Principal側の資格情報（Managed Identity等で生成されるもの）
- 対応するApplication側の資格情報（通常のクライアントシークレット/証明書）
- 各資格情報の有効期限と残り日数
- 期限切れの状態

## 特徴

- **包括的な調査**: Service PrincipalとApplicationの両方の資格情報を収集
- **期限監視**: 有効期限までの残り日数を自動計算
- **複数の資格情報タイプ**: パスワード（シークレット）と証明書の両方に対応
- **CSV出力**: Excel等で簡単に分析できるCSV形式で出力
- **UTF-8エンコーディング**: 日本語文字に対応

## 前提条件

### 必要な権限
- Azure CLIでのログイン
- テナント内のアプリケーション一覧の読み取り権限（`Directory.Read.All`等）

### 必要なツール
- PowerShell 5.1以上
- Azure CLI

## セットアップ

1. Azure CLIをインストール
2. 適切な権限でAzure ADにログイン：
   ```powershell
   az login --tenant <your-tenant-id>
   ```

## 使用方法

### 基本的な使用方法

```powershell
# デフォルトのファイル名（sp-credentials.csv）で出力
.\Export-SpCredentialExpiry.ps1

# カスタムパスで出力
.\Export-SpCredentialExpiry.ps1 -OutputPath "C:\Reports\credential-report.csv"
```

### パラメータ

| パラメータ | 説明 | デフォルト値 | 必須 |
|-----------|------|-------------|------|
| `OutputPath` | 出力CSVファイルのパス | `.\sp-credentials.csv` | いいえ |

## 出力形式

CSVファイルには以下の列が含まれます：

| 列名 | 説明 |
|-----|------|
| `Source` | 資格情報のソース（ServicePrincipal/Application） |
| `ServicePrincipalDisplayName` | Service Principalの表示名 |
| `ServicePrincipalObjectId` | Service PrincipalのオブジェクトID |
| `AppId` | アプリケーションID |
| `ApplicationObjectId` | ApplicationのオブジェクトID（該当する場合） |
| `SPCreatedDateTimeUtc` | Service Principalの作成日時（UTC） |
| `CredentialType` | 資格情報の種類（Password/Certificate） |
| `CredentialDisplayName` | 資格情報の表示名 |
| `KeyId` | 資格情報のキーID |
| `StartDateTimeUtc` | 有効開始日時（UTC） |
| `EndDateTimeUtc` | 有効期限日時（UTC） |
| `DaysToExpire` | 有効期限までの日数 |
| `IsExpired` | 期限切れかどうか（True/False） |

## 例

### 実行例

```powershell
PS C:\> .\Export-SpCredentialExpiry.ps1 -OutputPath ".\reports\sp-audit-2025-09-17.csv"
Getting Microsoft Graph access token via Azure CLI...
Fetching service principals...
Fetching applications...
Found 45 credential entries
Done. Exported 45 credential entries to .\reports\sp-audit-2025-09-17.csv (UTF-8 encoding)
```

### 出力CSVの例

```csv
Source,ServicePrincipalDisplayName,ServicePrincipalObjectId,AppId,SPCreatedDateTimeUtc,CredentialType,CredentialDisplayName,KeyId,StartDateTimeUtc,EndDateTimeUtc,DaysToExpire,IsExpired
Application,MyApp,12345678-1234-1234-1234-123456789012,87654321-4321-4321-4321-210987654321,2024-01-15T10:30:00.0000000Z,Password,ClientSecret1,abcd1234-...,2024-01-15T10:30:00.0000000Z,2025-01-15T10:30:00.0000000Z,120,False
```

## トラブルシューティング

### よくある問題

1. **認証エラー**
   ```
   Failed to acquire Graph access token. Please run: az login --tenant <your-tenant-id>
   ```
   **解決方法**: Azure CLIで正しいテナントにログインしてください。

2. **権限不足エラー**
   ```
   Error during HTTP request: Forbidden
   ```
   **解決方法**: `Directory.Read.All`権限が付与されていることを確認してください。

3. **資格情報が見つからない**
   ```
   No credentials found on service principals or applications.
   ```
   **解決方法**: テナントに資格情報を持つService Principalが存在するか確認してください。

## セキュリティに関する注意

- このスクリプトは資格情報の値そのものは収集しません（メタデータのみ）
- 出力CSVファイルには機密情報が含まれる可能性があるため、適切に管理してください
- 定期的な実行により、期限切れ前の資格情報更新を計画できます

## ライセンス

このプロジェクトはMITライセンスの下で公開されています。

## 貢献

バグ報告や機能要求は、GitHubのIssuesでお知らせください。プルリクエストも歓迎します。
