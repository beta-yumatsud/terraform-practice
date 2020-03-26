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

## 「第19章 高度な構文」のmemo
### 三項演算子
```hcl-terraform
variable "env" {}

resource "aws_instance" "example" {
  ami = "ami-0c3fd0f5d33134a76"
  instance_type = var.env == "prod" ? "m5.large" : "t3.micro"
}
```

### 複数リソース作成
```hcl-terraform
resource "aws_vpc" "examples" {
  count = 3
  cidr_block = "10.${count.index}.0.0/16"
}
```

### リソース制御
上記の三項演算子と複数リソース制御を組み合わせて下記のようなこともできる
```hcl-terraform
variable "allow_ssh" {
  type = bool
}

resource "aws_security_group_rule" "ingress" {
  count = var.allow_ssh ? 1 : 0
  // 以下省略
}
```

### 主要なデータソース
#### AWSアカウントID
```hcl-terraform
data "aws_caller_identity" "current" {}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}
```
#### リージョン
```hcl-terraform
data "aws_region" "current" {}

output "region_name" {
  value = data.aws_region.current.name
}
```

#### AZ
```hcl-terraform
data "aws_availability_zones" "available" {
  state = "available"
}

output "available_zones" {
  value = data.aws_availability_zones.available.names
}
```

#### サービスアカウント（各サービスごとの特殊なアカウント）
```hcl-terraform
data "aws_elb_service_account" "current" {}

output "alb_service_account_id" {
  value = data.aws_elb_service_account.current.id
}
```

### 主要な組み込み関数
* 試すには `terraform console` が便利
```
$ terraform console
> cidrsubnet("10.1.0.0/16", 8, 3)
10.1.3.0/24
```
* Numeric Functions: max, floor, powなど
* String Functions: substr, format, splitなど
* Collection Functions: flatten, concat, lengthなど
* Filesystem Functions: templatefile, fileexists, fileなど
* 他にもEncoding Functions, Date and Time Functions, Hash and Crypto Functions, IP Network Functionsなどがある

### マルチプロバイダ
マルチリージョンなどに使える。
```hcl-terraform
provider "aws" {
  alias = "virginia"
  region = "us-east-1"
}

provider "aws" {
  region = "ap-northeast-1"
}

resource "aws_vpc" "virginia" {
  provider = aws.virginia
  cidr_block = "192.168.0.0/16"
}

resource "aws_vpc" "tokyo" {
  cidr_block = "192.168.0.0/16"
}
```
→ moduleでも `providers` のように指定可能

### Dynamic Blocks
```hcl-terraform
variable "ports" {
  type = list(number)
}

resource "aws_security_group" "default" {
  name = "simple-sg"
  
  dynamic "ingress" {
    for_each = var.ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      cidr_blocks = ["0.0.0.0/0"]
      protocol    = "tcp"
    }
  }
}
```
→ これでmoduleで `ports` に3つのポートを渡せばingressルールが3つ作成できる

```hcl-terraform
variable "ingress_rules" {
  type = map(
    object(
      {
        port         = number
        cider_blocks = list(string)
      }
    )
  )
}

resource "aws_security_group" "default" {
  name = "complex-sg"
  
  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.port
      to_port     = ingress.value.port
      cidr_blocks = ingress.value.cider_blocks
      description = "Allow ${ingress.key}"
      protocol    = "tcp"
    }
  }
}
```
→ これでmoduleとして呼び出し側が `ingress_rules` に指定してあげれば特定のルールで作成可能。

## 「第22章 モジュール設計」のmemo
Standard Module Structure
```
├─ LICENSE
├─ README.md
├─ main.tf
├─ variables.tf
├─ outputs.tf
├─ modules/
|  ├─ nestedA/
|  |  ├─ README.md
|  |  ├─ variables.tf
|  |  ├─ main.tf
|  |  ├─ outputs.tf
|  ├─ nestedB/
├─ examples/
|  ├─ exampleA/
|  |  ├─ main.tf
|  ├─ exampleB/
```
→ variableとoutputは `description` で定義しましょう！
→ これは外部に公開する場合とかに参考にしましょう？かな。
→ `Terraform Module Registry` という場所があり、誰でもModuleを公開できるらしい（mjdk）
→ 公開moduleの利用の仕方は下記
```hcl-terraform
module "ec2_instance" {
  source = "terraform-aws-modules/ec2-instance/aws"
  version = "2.6.0"
  // モジュールのパラメータを指定
}
```

## その他
* `tfstate` ファイルは `Terraform Cloud` を使うことも可能
* module分割はちゃんとしようぜ
* 環境ごとに分けるは `ディレクトリを分けてしまう` が多数派で、 `workspaceで分ける` は少数派みたい（自分はworkspace派）
* コンポーネント分割は下記のような視点で分けると良さげ
  * 安定度が高い（変更がしづらく、他のコンポーネントから参照される、ネットワークなど）
  * ステートフル（RDSなど）
  * 影響範囲（ユーザに影響が出るものと、CI/CDのようにそこまで影響が出ない: これはサービスによりそうだけどものと分ける的な）
  * 組織のライフサイクル（IAMユーザなど）
  * 要は関心ごとの分離をしませう

# 参考
* [公式ドキュメント](https://www.terraform.io/docs/index.html)
