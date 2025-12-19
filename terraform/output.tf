output "alb_dns" {
  value = aws_lb.k8s_master_nlb.dns_name
}