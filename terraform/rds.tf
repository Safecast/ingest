variable "rds-prd-password" {}

resource "aws_db_instance" "prd" {
  allocated_storage = 10
  engine            = "postgres"
  engine_version    = "9.5.4"
  instance_class    = "db.t2.micro"
  name              = "safecast"
  username          = "safecast"
  password          = "${var.rds-prd-password}"

  vpc_security_group_ids = ["${aws_security_group.rds-prd.id}"]

  tags {
    Name = "safecastingest-prd"
  }
}
