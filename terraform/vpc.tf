data "aws_vpc" "default" {
  filter {
    name   = "tag:Name"
    values = ["default"]
  }
}
