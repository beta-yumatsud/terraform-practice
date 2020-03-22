# memo
## 「第17章 Terraform Best Practice」メモ
### バージョンの固定
* Terraformバージョンの固定
```hcl-terraform
terraform {
  required_version = "0.12.5"
}
```
→ `.terraform-version` とかでバージョン指定してtfenvでinstallさせるとかもあり。

* プロバイダバージョンの固定
```hcl-terraform
provider "aws" {
  version = "2.20.0"
}
```

いずれもバージョンを固定したら `terraform init` を実行しておく。

### 削除操作の抑止
削除されると困るリソースは下記のように `prevent_destory` を入れておこう！（全リソースに設定可能）
```hcl-terraform
resource "aws_s3_bucket" "example" {
  bucket = "example"

  lifecycle {
    prevent_destroy = true
  }
}
```

### コードフォーマット
* サブディレクトリ配下も含めて実施する場合
```shell script
$ terraform fmt -recursive
```
* フォーマット済みかどうかのチェック
```shell script
$ terraform fmt -recursive -check
```
→ これでCI回せばチェックで引っかかるのか^^

### バリデーション
* 構文チェックや変数に値をセットしているかなど。 `terraform init` していないとエラーになるみたい
```shell script
$ terraform validate
```
* サブディレクトリとかまでやる場合はちょっと工夫が必要
```shell script
$ find . -type f -name '*.tf' -exec dirname {} \; | sort -u |  | xargs -I {} terraform validate {}
```

### オートコンプリート
```shell script
$ terraform -install-autocomplete
```

### プラグインのキャッシュ
* `.terraformrc` ファイルをホームディレクトリに作成
```shell script
plugin_cache_dir = "$HOME/.terraform.d/plugin-cache"
```
* 上記のディレクトリ作成しておけばキャッシュされる
```shell script
$ mkdir -p "$HOME/.terraform.d/plugin-cache"
```

### TFLint
* install for Mac
```shell script
$ brew install tflint

$ tflint --version
```
* 使い方その1
```shell script
$ tflint
```
→ サブディレクトリを再起的にチェックするわけではない点に注意
* 使い方その2: AWS APIを利用して詳細なチェック
```shell script
$ tflint --deep --aws-region=ap-northeast-1
```


# 参考
* [公式ドキュメント](https://www.terraform.io/docs/index.html)
