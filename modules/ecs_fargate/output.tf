#Grafana Public IP
output "grafan_public_ip" {
  description = "Grafana service public IP"
  value = aws_ecs_service.grafana_service.network_configuration[0].assign_public_ip
}

#NGINX Public IP
output "nginx_public_ip" {
  description = "NGINX service public IP"
  value = aws_ecs_service.nginx_service.network_configuration[0].assign_public_ip
}