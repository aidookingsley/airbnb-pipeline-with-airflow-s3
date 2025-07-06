resource "random_id" "suffix" {
  byte_length = 4
}
locals {
  bucket_name = "${var.project}-bucket-${random_id.suffix.hex}"
  table_name  = "${var.project}-table"
}
