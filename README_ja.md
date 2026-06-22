# SSH Public Key Manager

## 概要

SSH Public Key Manager は、`${HOME}/.ssh/authorized_keys` に登録されているSSH公開鍵をWebブラウザから管理するための Open OnDemand Passenger アプリです。Open OnDemandからSSH公開鍵の登録・削除を行いたいHPCクラスタユーザを対象としています。

### セキュリティについて

- 公開鍵は `ssh-keygen -lf` で形式を検証してから登録します。不正な形式の入力は拒否されます。
- 既存の鍵とフィンガープリントが一致する場合、重複登録を拒否します。
- `~/.ssh`（700）・`authorized_keys`（600）のパーミッションは、SSHの要件に従って自動的に設定されます。
- CSRF対策として `Rack::Protection::AuthenticityToken` を有効化しています。セッション署名用の秘密値は `~/.config/ssh_key_manager/session_secret`（600）に保存され、Passengerの再起動後も維持されます。

### ファイル構成

```
.
├── app.rb                  # Sinatraアプリ本体（一覧・登録・削除のルーティングとロジック）
├── config.ru               # Passenger / Rack のエントリポイント
├── manifest.yml            # Open OnDemand アプリのマニフェスト
├── appearance.yml.example  # 外観設定のサンプル（appearance.yml にコピーして使用）
├── misc/                   # ローカルテスト専用ファイル（Gemfile、スクリーンショット等）
└── views/
    ├── layout.erb  # 共通レイアウト（Bootstrap読み込み）
    └── index.erb   # 鍵一覧・登録フォーム
```

## スクリーンショット

![Screenshot](misc/screen.png)

## 機能

- 登録済み公開鍵の一覧表示（種別 / SHA256フィンガープリント / コメント）
- 複数の公開鍵を管理可能
- 公開鍵の新規登録（形式検証・重複チェック付き）
- 公開鍵の削除（フィンガープリント指定）

## 必要要件

### Open OnDemand

- Open OnDemand 3.0 以上
- `ssh-keygen`（公開鍵の検証・フィンガープリント取得に使用）

## インストール

### 1. リポジトリのクローン

```bash
cd /var/www/ood/apps/sys/
git clone https://github.com/OpenOnDemandJP/SshPublicKeyManager.git
```

### 2. サイトに合わせた設定

#### 外観のカスタマイズ（オプション）

`appearance.yml.example` を `appearance.yml` にコピーして色を編集します。

```bash
cp appearance.yml.example appearance.yml
```

```yaml
navbar_bg:     "#212529"  # ナビバーの背景色
navbar_text:   "#ffffff"  # ナビバーのテキスト・リンク色
body_bg:       "#f8f9fa"  # ページ背景色
primary_color: "#0d6efd"  # カードヘッダーとAddボタンの背景色
primary_text:  "#ffffff"  # カードヘッダーとAddボタンのテキスト色
```

編集後はOpen OnDemandを再起動（ナビゲーションバーの「Help」の「Restart Web Server」をクリック）すると反映されます。

### 3. 確認

OODダッシュボードの **Files** カテゴリに **SSH Public Key** が表示されていれば完了です。

## 使い方

ブラウザでアプリを開くと、登録済みの公開鍵の一覧と、新規登録用のフォームが表示されます。

- **Registered Public Keys**: 登録済みの各鍵の種別・SHA256フィンガープリント・コメントが表示されます。**Delete** ボタンで鍵を削除できます（削除対象はフィンガープリントで識別されます）。
- **Add a Public Key**: テキストエリアに公開鍵を1件（例: `id_ed25519.pub` の内容）貼り付けて **Add** をクリックします。登録前に形式が検証され、重複する鍵は拒否されます。

## トラブルシューティング

バグ報告や機能要望は、詳細なログと再現手順を添えて [Issue](https://github.com/OpenOnDemandJP/SshPublicKeyManager/issues) を作成してください。

## ローカルでのテスト

### セットアップ

リポジトリを取得し、依存gemをインストールします。

```bash
git clone https://github.com/OpenOnDemandJP/SshPublicKeyManager.git
cd SshPublicKeyManager
export BUNDLE_GEMFILE=$PWD/misc/Gemfile
bundle install
```

`misc/Gemfile` はローカルでのテスト専用です（Open OnDemand上での実行には不要なため、リポジトリのトップレベルには置いていません）。以降のコマンドも、同じシェルで `BUNDLE_GEMFILE` を設定したまま実行してください。

### 安全に試す（推奨）

実際の `~/.ssh/authorized_keys` を変更せずに動作確認したい場合は、`HOME` を一時ディレクトリに向けて起動します。

```bash
HOME=$(mktemp -d) bundle exec rackup -p 9292
```

ブラウザで http://localhost:9292 を開いてください。

テスト用の鍵は以下のように生成できます。

```bash
ssh-keygen -t ed25519 -f /tmp/testkey -N '' -C 'test@local'
cat /tmp/testkey.pub
```

### 実際の `~/.ssh/authorized_keys` で動かす

```bash
bundle exec rackup -p 9292
```

この場合、画面での操作が実際の `~/.ssh/authorized_keys` を書き換えます。事前にバックアップを取ることを推奨します。

```bash
cp ~/.ssh/authorized_keys ~/.ssh/authorized_keys.bak
```

## 既知の制限事項

- 公開鍵の保存場所は `${HOME}/.ssh/authorized_keys` に固定されています。
- LDAPに直接登録するなど、`authorized_keys` 以外で公開鍵を管理している環境には対応していません。

## コントリビューション

議論や質問は [GitHub Discussions](https://github.com/OpenOnDemandJP/SshPublicKeyManager/discussions) をご利用ください。

## 参考

- [Open OnDemand](https://openondemand.org/) — HPCポータルフレームワーク

## ライセンス

[MIT License](LICENSE)
