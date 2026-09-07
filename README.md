# S5 Stack

**Igniteで画面を、Vaporでサーバーを。共有するSwiftの型で両者をつなぐWebアプリ開発スタックです。**

| 層 | 技術 | 担当 |
| --- | --- | --- |
| Site | [Ignite](https://github.com/twostraws/Ignite) | SwiftでHTMLとレイアウトを記述 |
| Schema | S5 | APIの入力・出力・バリデーション・バージョンを共有 |
| Service | [Vapor](https://github.com/vapor/vapor) + S5Vapor | 型付きハンドラーをHTTP APIとして公開 |
| Store | [Fluent](https://github.com/vapor/fluent) | SQLite / PostgreSQL、モデル、マイグレーション |
| Ship | s5 CLI + Docker + [Nido](https://github.com/Moriya-Taichi/Nido) | プロジェクト生成、ビルド、インフラ定義・適用 |

Nidoは独立したIaCパッケージとして利用します。生成アプリの`Infrastructure/`がNidoのコミットを固定して参照し、
`s5 infra`から構成生成・plan・apply・構成図出力を実行します。Webアプリ本体とS5のランタイムにはNidoの依存を追加しません。

## 始める

Swift 6.2以降を使用します。macOSはXcode 26.2以降、LinuxはSwift 6.2でCIを実行します。

```sh
git clone https://github.com/Moriya-Taichi/S5-Stack.git
cd S5-Stack
swift build --product s5

S5_ROOT="$PWD"
S5_CLI="$PWD/.build/debug/s5"
"$S5_CLI" new MyApp --directory .. --s5-path "$S5_ROOT"
cd ../MyApp
"$S5_CLI" dev
```

`http://localhost:8080`を開くと、メモを作成・完了・削除できるサンプルが動きます。
データはSQLiteに保存され、画面を再読み込みしても保持されます。`dev`はIgniteをビルドしてから
Vaporを起動します。編集後はコマンドを再起動してください。

`--s5-path`はS5自体の開発に使うローカル依存です。通常のアプリでは次のようにS5のコミットを固定できます。

```sh
s5 new MyApp --revision <40文字のコミットSHA>
```

依存指定を省略すると`main`を参照します。初期実装のPRを試す場合はそのブランチをチェックアウトし、
`--s5-path`を使ってください。生成したアプリの`Package.resolved`はコミットして管理します。

## APIを一度定義する

画面とサーバーが使う`AppContract`ターゲットに、公開するDTOとAPI契約を置きます。

```swift
import S5

enum Greeting: Endpoint {
    struct Input: Codable, Sendable {
        let name: String
    }

    struct Output: Codable, Sendable {
        let message: String
    }

    static let name = "greeting"

    static func validate(_ input: Input) throws {
        guard !input.name.isEmpty else {
            throw APIError.invalidInput("Name is required.")
        }
    }
}
```

サーバーでは、契約を満たす処理を登録します。

```swift
import S5Vapor

try app.endpoint(Greeting.self) { input, request in
    Greeting.Output(message: "Hello, \(input.name)")
}
```

`POST /api/v1/greeting`が登録されます。JSONのデコードと入力検証はS5Vaporが行い、
ハンドラーの引数・戻り値はSwiftのコンパイラが検査します。DBモデルはサーバー内部に置き、
公開するDTOへの変換を明示します。

Swiftクライアントは契約をそのまま使います。Swiftのスタブ生成やマクロは必要ありません。

```swift
import Foundation
import S5Client

let client = try APIClient(baseURL: URL(string: "https://example.com")!)
let result = try await client.call(Greeting.self, input: .init(name: "Swift"))
print(result.message)
```

`APIClient`はURLSessionを標準で使い、独自トランスポートと、リクエストごとに更新できる認証ヘッダーを受け取れます。
通信キャンセルはURLSessionに伝播します。更新操作の重複を避けるため、自動リトライは行いません。

## Igniteとブラウザをつなぐ

Igniteはビルド時にHTMLを生成します。Swiftをブラウザで実行する構成ではありません。
S5Igniteはサイト生成時にAPIカタログから`Public/s5/client.mjs`を生成します。

```swift
import S5
import S5Ignite

var catalog = EndpointCatalog()
try catalog.register(Greeting.self, as: "greet")
try await site.publish(api: catalog, sourceDirectory: root,
                       buildDirectory: root.appendingPathComponent("Public"))
```

ブラウザのイベント処理から、生成したクライアントを呼びます。

```javascript
import { api } from './s5/client.mjs';

const result = await api.greet({ name: 'Swift' });
element.textContent = result.message;
```

APIのURLはSwiftの契約から生成されます。JavaScriptの動的な値にはSwiftのコンパイル時型検査が働かないため、
サーバー側で必ずデコードとバリデーションを行います。ブラウザクライアントは同一オリジンのAPIを呼びます。
Int64などJavaScriptの安全な整数範囲を超える値は、文字列のDTOにするなど通信形式を明示してください。

## パッケージとコマンド

| 製品 | 役割 |
| --- | --- |
| `S5` | `Endpoint`、`Empty`、`APIError`、`EndpointCatalog`、共通JSON codec |
| `S5Client` | Codableとasync/awaitに基づくSwift HTTPクライアント |
| `S5Vapor` | Vaporへのエンドポイント登録とエラーレスポンス統一 |
| `S5Ignite` | Igniteのサイト生成とブラウザ向けクライアント生成 |
| `S5Scaffold` | 既存ファイルを上書きしないプロジェクト生成 |
| `s5` | 生成・ビルド・開発用CLI |

| コマンド | 動作 |
| --- | --- |
| `s5 new MyApp` | 独立したSwift Packageを生成 |
| `s5 dev` | 画面をビルドしてVaporをローカル起動 |
| `s5 build --release` | 最適化したサーバー実行ファイルと`Public/`を生成 |
| `s5 infra <Nidoの引数>` | 独立したInfrastructureパッケージのNido CLIを実行 |

生成したアプリは通常のSwift Packageとして編集できます。CLIを使わずに`swift run Frontend`、
`swift run Server`、`swift test`を実行することもできます。Swiftクライアント向けに`AppContract`をライブラリ製品として公開しています。

## 永続化とデプロイ

サンプルにはFluentのモデルとマイグレーション、SQLiteとPostgreSQLのドライバーが含まれます。
ローカルでは`db.sqlite`を使用し、`DATABASE_URL`があればPostgreSQLに切り替わります。
開発環境では起動時にマイグレーションし、本番環境では明示的に実行します。

```sh
swift run Server migrate --env production --yes
swift run Server serve --env production --hostname 0.0.0.0 --port 8080
```

Dockerfileと、ローカルでPostgreSQLも起動するCompose設定を生成します。具体的な手順は生成されたREADMEを参照してください。
DockerビルドではS5にリモートのコミット依存を使います。ビルドコンテキスト外の`--s5-path`はコンテナから参照できません。

## Nidoでデプロイする

`s5 new`は`Infrastructure/Package.swift`とSwiftのインフラ定義も生成します。
NidoとDockerプロバイダーのバージョンは固定しています。Nido CLIはSwiftPMが依存から実行するため、別途インストールする必要はありません。

```sh
# 生成したアプリのディレクトリで実行。構成と図の生成だけならDockerやTerraformは不要。
s5 infra synth
s5 infra --skip-synth diagram --format svg --output architecture.svg

# Docker EngineとTerraform 1.5+を用意し、S5をリモート依存にしたアプリをビルド。
docker build -t myapp:release-1 .
export TF_VAR_image=myapp:release-1
s5 infra init
s5 infra plan -out=review.tfplan
s5 infra --skip-synth apply review.tfplan
s5 infra output
```

初期構成は**ローカルDockerへのデプロイ**です。Nidoがイメージ、SQLiteの永続ボリューム、
マイグレーション用コンテナ、アプリコンテナを管理します。マイグレーションの終了コードを検証してからアプリを起動し、
`/ready`でDBの準備完了を確認します。公開先は`http://127.0.0.1:8080`です。
Composeや`s5 dev`も8080番を使うため、同時には起動しないでください。

更新時は新しいタグまたはレジストリのdigestを`TF_VAR_image`に指定してplan/applyします。同じタグの上書きは検出対象にしません。
SQLiteは単一アプリ向けです。破壊的なスキーマ変更には停止・バックアップを含む移行手順を用意してください。
クラウド上への配置やPostgreSQLの構築は、`Infrastructure`の定義をNidoの各クラウド用APIで拡張します。

`--engine tofu`などのオプション、保存済みプラン、終了コードはNidoにそのまま渡します。
stateは`Infrastructure/.nido/`に置き、S5側では複製しません。`Infrastructure/Package.resolved`と
`Infrastructure/.nido/.terraform.lock.hcl`で依存を管理してください。
`s5 infra destroy`はアプリと**SQLiteのデータボリュームも削除**する操作です。

以前のS5で作成したアプリには、新しい`s5 new`で生成した`Infrastructure/`をコピーし、コンテナのhealthcheckで使う`curl`をDockerfileに追加してください。
既存のComposeリソースやデータを自動で取り込む機能はありません。

## 保証範囲

- Swiftの入力型・出力型・ハンドラーの対応をコンパイル時に検査します。
- 不正JSON・入力検証・本文サイズ制限・認証ミドルウェアの拒否をサーバーで扱います。
- サーバーの内部エラーの詳細をクライアントに返しません。
- サンプルは認証なしの共有ノートです。ログインやユーザーごとの所有権はアプリ側で実装します。
- `Endpoint.version`で通信バージョンを指定できます。過去に配布したクライアントとの互換性の自動検証は含みません。
- 認証基盤、リアルタイム購読、キャッシュ、ファイル監視、クラウド別のデプロイテンプレートはこの初期実装に含めていません。

## 検証

```sh
swift test --parallel
node --test Tests/Browser/runtime.test.mjs
```

CIはmacOSとLinuxでライブラリをテストし、CLIで生成したアプリについてDBを含むCRUDテストとIgniteのビルドを実行します。
LinuxではChromiumから実際のVaporサーバーに接続し、作成・再読み込み・完了・削除、HTMLを含む入力の表示、
モバイル幅でのレイアウトを確認します。

Nido連携は構成と図の生成、Terraformのvalidate、保存済みplanの適用、ブラウザ操作、差分のない再plan、コンテナ再作成後の永続化をCIで検証します。
