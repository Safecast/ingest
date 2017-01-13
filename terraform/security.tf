resource "aws_security_group" "rds-prd" {
  vpc_id = "${data.aws_vpc.default.id}"

  name        = "rds-safecastingest-prd"
  description = "rds-safecastingest-prd"
}

data "aws_security_group" "safecastingest-prd" {
  vpc_id = "${data.aws_vpc.default.id}"

  filter {
    name   = "tag:elasticbeanstalk:environment-name"
    values = ["safecastingest-prd"]
  }

  filter {
    name   = "tag:aws:cloudformation:logical-id"
    values = ["AWSEBSecurityGroup"]
  }
}

resource "aws_security_group_rule" "safecastingest-prd-to-rds-prd" {
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = 5432
  to_port                  = 5432
  source_security_group_id = "${data.aws_security_group.safecastingest-prd.id}"
  security_group_id        = "${aws_security_group.rds-prd.id}"
}
