terraform {
  backend "s3" {
    bucket = "tfstate-pragmatic-terraform"
    key    = "example/terraform.state"
    region = "ap-northeast-1"
  }
}

/*
data "terraform_remote_state" "hogehoge" {
  backend = "s3"
  config {
    bucket = "tfstate-pragmatic-terraform"
    key    = "example/terraform.state"
    region = "ap-northeast-1"
  }
}
// data.terraform_remote_state.hogehoge.とかで使うお

// 他にもSSMパラメータストアとかでも連携できるみたい
// dataソースに定義をしてそいつを参照するというのもあり、tagで参照先をfiltering可能

// Data-only Moduleという方法もあるのか。これは読みやすくなって良いかも
*/
