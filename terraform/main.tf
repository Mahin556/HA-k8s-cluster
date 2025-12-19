resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr
  tags = {
    "Name" = "my-vpc"
  }
}

resource "aws_subnet" "my_subnet" {
  count = var.subnet_count
  vpc_id = aws_vpc.vpc.id
  #cidr_block = "${local.vpc_prefix_2_octets}.${count.index+1}.0/24"
  cidr_block = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = element(local.availability_zones,count.index)
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    "Name" = "my-igw"
  }
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    "Name" = "my-rt"
  }
  route {
    gateway_id = aws_internet_gateway.igw.id
    cidr_block = "0.0.0.0/0"
  }
}

resource "aws_route_table_association" "rt_association" {
  count = length(aws_subnet.my_subnet)
  route_table_id = aws_route_table.rt.id
  subnet_id = aws_subnet.my_subnet[count.index].id
}

resource "aws_security_group" "sg" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "my-sg"
  }

  dynamic "ingress" {
    for_each = var.inbound_rules
    content {
      from_port = ingress.value.from
      to_port   = coalesce(ingress.value.to, ingress.value.from)
      protocol  = coalesce(ingress.value.protocol, "tcp")
      description = coalesce(ingress.value.description, "null")
      cidr_blocks = coalesce(ingress.value.cidr_block, ["0.0.0.0/0"])
    }
  }

  dynamic "egress" {
    for_each = var.outbound_rules
    content {
      from_port = egress.value.from
      to_port   = coalesce(egress.value.to, egress.value.from)
      protocol  = coalesce(egress.value.protocol, "-1")
      description = coalesce(egress.value.description, "null")
      cidr_blocks = coalesce(egress.value.cidr_block, ["0.0.0.0/0"])
    }
  }
}

 
resource "aws_instance" "control_nodes" {
  count = var.control_nodes_count
  ami = data.aws_ami.ami.id
  instance_type = var.control_instance_type
  vpc_security_group_ids = [aws_security_group.sg.id]
  key_name = var.key
  subnet_id = aws_subnet.my_subnet[0].id
  associate_public_ip_address = true
  tags = {
    "Name" = "control-node-${count.index+1}"
  }
}

resource "aws_instance" "worker_nodes" {
  count = var.worker_nodes_count
  ami = data.aws_ami.ami.id
  instance_type = var.worker_instance_type
  vpc_security_group_ids = [aws_security_group.sg.id]
  key_name = var.key
  subnet_id = aws_subnet.my_subnet[0].id
  associate_public_ip_address = true
  tags = {
    "Name" = "worker-node-${count.index+1}"
  }
}

resource "aws_instance" "haproxy_nodes" {
  count = var.hp_proxy_count
  ami = data.aws_ami.ami.id
  instance_type = var.proxy_instance_type
  vpc_security_group_ids = [aws_security_group.sg.id]
  key_name = var.key
  subnet_id = aws_subnet.my_subnet[1].id
  associate_public_ip_address = true
  tags = {
    "Name" = "ha-node-${count.index+1}"
  }
}

