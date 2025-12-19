region              = "ap-south-1"
profile             = "tf-user"
vpc_cidr            = "10.0.0.0/16"
key                 = "ssh-key"
subnet_count        = 2
control_nodes_count = 3
worker_nodes_count  = 2
inbound_rules = [
  {
    from     = 22
    to       = 22
    protocol = "tcp"
  },
  {
    from     = 6443
    to       = 6443
    protocol = "tcp"
  },
  {
    from     = 2379
    to       = 2380
    protocol = "tcp"
  },
  {
    from     = 10250
    to       = 10250
    protocol = "tcp"
  },
  {
    from     = 10256
    to       = 10257
    protocol = "tcp"
  },
  {
    from     = 10259
    to       = 10259
    protocol = "tcp"
  },
  {
    from     = 30000
    to       = 32767
    protocol = "tcp"
  },
  {
    from     = 30000
    to       = 32767
    protocol = "udp"
  },
  {
    from     = 30000
    to       = 32767
    protocol = "tcp"
  },
  {
    from     = 443
    to       = 443
    protocol = "tcp"
  },
  {
    from     = 80
    to       = 80
    protocol = "tcp"
  },
  {
    from     = 8404
    to       = 8404
    protocol = "tcp"
  },
  {
    from     = 4789
    to       = 4789
    protocol = "udp"
  },
  {
    from     = 8472
    to       = 8472
    protocol = "udp"
  },
  {
    from     = 179
    to       = 179
    protocol = "tcp"
  },
  
]

outbound_rules = [{
  from = 0
  to   = 0
  protocol = "-1"
}]

worker_instance_type = "t2.small"
control_instance_type = "t2.medium"

