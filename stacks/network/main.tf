# Network Shared Module
module "network_shared" {
  source = "../../modules/network_shared"

  environment            = var.environment
  vpc_cidr              = var.vpc_cidr
  availability_zones    = var.availability_zones
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  enable_nat_gateway    = var.enable_nat_gateway
  enable_vpn_gateway    = var.enable_vpn_gateway
  enable_vpc_endpoints  = var.enable_vpc_endpoints
  
  tags = var.default_tags
}
