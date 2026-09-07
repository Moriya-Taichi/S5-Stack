# S5 Stack

**Igniteで画面を、Vaporでサーバーを。共有するSwiftの型で両者をつなぐWebアプリ開発スタックです。**

| 層 | 技術 | 担当 |
| --- | --- | --- |
| Site | [Ignite](https://github.com/twostraws/Ignite) | SwiftでHTMLとレイアウトを記述 |
| Schema | S5 | APIの入力・出力・バリデーション・バージョンを共有 |
| Service | [Vapor](https://github.com/vapor/vapor) + S5Vapor | 型付きハンドラーをHTTP APIとして公開 |
| Store | [Fluent](https://github.com/vapor/fluent) | SQLite / PostgreSQL、モデル、マイグレーション |
| Ship | s5 CLI + Docker | プロジェクト生成、開発起動、成果物のビルド |

Nidoは独立したIaCプロジェクトです。S5はNidoを依存に含めず、クラウドリソースも作成しません。
生成したコンテナイメージや環境変数を、Nidoなど任意のデプロイツールで扱えます。

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

## 保証範囲

- Swiftの入力型・出力型・ハンドラーの対応をコンパイル時に検査します。
- 不正JSON・入力検証・本文サイズ制限・認証ミドルウェアの拒否をサーバーで扱います。
- サーバーの内部エラーの詳細をクライアントに返しません。
- サンプルは認証なしの共有ノートです。ログインやユーザーごとの所有権はアプリ側で実装します。
- `Endpoint.version`で通信バージョンを指定できます。過去に配布したクライアントとの互換性の自動検証は含みません。
- 認証基盤、リアルタイム購読、キャッシュ、ファイル監視、IaCはこの初期実装に含めていません。

## 検証

```sh
swift test --parallel
node --test Tests/Browser/runtime.test.mjs
```

CIはmacOSとLinuxでライブラリをテストし、CLIで生成したアプリについてDBを含むCRUDテストとIgniteのビルドを実行します。
LinuxではChromiumから実際のVaporサーバーに接続し、作成・再読み込み・完了・削除、HTMLを含む入力の表示、
モバイル幅でのレイアウトを確認します。
