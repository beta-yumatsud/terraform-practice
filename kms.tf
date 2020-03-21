## KMS
resource "aws_kms_key" "example" {
  description             = "Example Customer Master Key"
  enable_key_rotation     = true
  is_enabled              = true
  deletion_window_in_days = 30
  // カスタマーマスターキーの削除は推奨されていないので、基本的には無効化することで対応するのが良いんだってばよ
}

resource "aws_kms_alias" "example" {
  name          = "alias/example" # prefixとして「alias/」が必要なんだってばよ
  target_key_id = aws_kms_key.example.key_id
}