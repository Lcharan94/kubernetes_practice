output "default_vpc_id" {
  value = data.aws_vpc.default.id
}

output "default_vpc_cidr_block" {
  value = data.aws_vpc.default.cidr_block
}

output "default_security_group_id" {
  value = data.aws_security_group.default.id
}

