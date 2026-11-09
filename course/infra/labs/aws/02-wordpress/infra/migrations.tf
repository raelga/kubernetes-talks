# Removing the optional database must not recreate an existing database.
moved {
  from = aws_security_group.database[0]
  to   = aws_security_group.database
}
moved {
  from = aws_vpc_security_group_ingress_rule.database[0]
  to   = aws_vpc_security_group_ingress_rule.database
}
moved {
  from = aws_vpc_security_group_egress_rule.database[0]
  to   = aws_vpc_security_group_egress_rule.database
}
moved {
  from = aws_db_subnet_group.app[0]
  to   = aws_db_subnet_group.app
}
moved {
  from = aws_db_instance.app[0]
  to   = aws_db_instance.app
}
