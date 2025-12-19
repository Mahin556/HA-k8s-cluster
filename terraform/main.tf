resource "aws_vpc" "k8s_vpc" {
  cidr_block = var.vpc_cidr
  tags = {
    "Name" = "k8s-vpc"
  }
}

resource "aws_subnet" "k8s_subnet" {
  count = var.subnet_count
  vpc_id = aws_vpc.k8s_vpc.id
  #cidr_block = "${local.vpc_prefix_2_octets}.${count.index+1}.0/24"
  cidr_block = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = element(locals.availability_zones,count.index)
}

resource "aws_internet_gateway" "k8s_igw" {
  vpc_id = aws_vpc.k8s_vpc.id
  tags = {
    "Name" = "k8s-igw"
  }
}

resource "aws_route_table" "k8s_rt" {
  vpc_id = aws_vpc.k8s_vpc.id
  tags = {
    "Name" = "k8s-rt"
  }
  route {
    gateway_id = aws_internet_gateway.k8s_igw.id
    cidr_block = "0.0.0.0/0"
  }
}

resource "aws_route_table_association" "rt_association" {
  count = length(aws_subnet.k8s_subnet)
  route_table_id = aws_route_table.k8s_rt.id
  subnet_id = aws_subnet.k8s_subnet[count.index].id
}

resource "aws_security_group" "k8s_sg" {
  vpc_id = aws_vpc.k8s_vpc.id

  tags = {
    Name = "k8s-sg"
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
  vpc_security_group_ids = [aws_security_group.k8s_sg.id]
  key_name = var.key
  subnet_id = element(aws_subnet.k8s_subnet[*].id,count.index)
  associate_public_ip_address = true
  tags = {
    "Name" = "control-node-${count.index+1}"
  }
}

resource "aws_instance" "worker_nodes" {
  count = var.worker_nodes_count
  ami = data.aws_ami.ami.id
  instance_type = var.worker_instance_type
  vpc_security_group_ids = [aws_security_group.k8s_sg.id]
  key_name = var.key
  subnet_id = element(aws_subnet.k8s_subnet[*].id,count.index)
  associate_public_ip_address = true
  tags = {
    "Name" = "worker-node-${count.index+1}"
  }
}

# -----------------------
# Network Load Balancer (for K8s masters)
# -----------------------
resource "aws_lb" "k8s_master_nlb" {
  name                             = "k8s-master-nlb"
  internal                         = false
  load_balancer_type               = "network"
  security_groups = [aws_security_group.k8s_sg.id]
  subnets                          = aws_subnet.k8s_subnet[*].id
  enable_cross_zone_load_balancing = true

  tags = {
    Name = "k8s-master-nlb"
  }
}

# Target Group for API server (port 6443)
resource "aws_lb_target_group" "k8s_master_tg" {
  name        = "k8s-master-tg"
  port        = 6443
  protocol    = "TCP"
  vpc_id      = aws_vpc.k8s_vpc.id
  target_type = "instance"
  health_check {
    port                = "6443"
    protocol            = "TCP"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 10
  }

  tags = {
    Name = "k8s-master-tg"
  }
}

# Register all master nodes with the target group
resource "aws_lb_target_group_attachment" "k8s_master_attach" {
  count            = length(aws_instance.control_nodes)
  target_group_arn = aws_lb_target_group.k8s_master_tg.arn
  target_id        = aws_instance.control_nodes[count.index].id
  port             = 6443
}

# Listener for API Server
resource "aws_lb_listener" "k8s_master_listener" {
  load_balancer_arn = aws_lb.k8s_master_nlb.arn
  port              = 6443
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.k8s_master_tg.arn
  }
}

