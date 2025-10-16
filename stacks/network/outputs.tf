output "vpc_id" {
  description = "VPC ID"
  value       = module.network_shared.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = module.network_shared.vpc_cidr
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.network_shared.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.network_shared.private_subnet_ids
}

output "nat_gateway_ids" {
  description = "NAT Gateway IDs"
  value       = module.network_shared.nat_gateway_ids
}
