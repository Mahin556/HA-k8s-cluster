locals {
  vpc_prefix_2_octets = join(".", slice(split(".", cidrhost(var.vpc_cidr, 0)), 0, 2))
  availability_zones = [for az in data.aws_availability_zones.names.names: az if az != "ap-south-1c"]
}