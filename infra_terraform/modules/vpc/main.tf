variable "cidr" { type = string }
variable "az_count" { type = number default = 3 }
variable "name" { type = string }
variable "tags" { type = map(string) default = {} }

data "aws_availability_zones" "available" {}
locals { azs = slice(data.aws_availability_zones.available.names, 0, var.az_count) }

resource "aws_vpc" "this" {
  cidr_block = var.cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = merge(var.tags, { Name = "${var.name}-vpc" })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.this.id
  tags = merge(var.tags, { Name = "${var.name}-igw" })
}

resource "aws_subnet" "public" {
  count = var.az_count
  vpc_id = aws_vpc.this.id
  cidr_block = cidrsubnet(var.cidr, 4, count.index)
  availability_zone = local.azs[count.index]
  map_public_ip_on_launch = true
  tags = merge(var.tags, { Name = "${var.name}-public-${count.index}", "kubernetes.io/role/elb" = "1" })
}
resource "aws_subnet" "private" {
  count = var.az_count
  vpc_id = aws_vpc.this.id
  cidr_block = cidrsubnet(var.cidr, 4, count.index + 8)
  availability_zone = local.azs[count.index]
  tags = merge(var.tags, { Name = "${var.name}-private-${count.index}", "kubernetes.io/role/internal-elb" = "1" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route { cidr_block = "0.0.0.0/0" gateway_id = aws_internet_gateway.igw.id }
  tags = merge(var.tags, { Name = "${var.name}-public-rt" })
}
resource "aws_route_table_association" "public" {
  count = var.az_count
  subnet_id = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" { vpc = true depends_on = [aws_internet_gateway.igw] }
resource "aws_nat_gateway" "nat" {
  subnet_id     = aws_subnet.public[0].id
  allocation_id = aws_eip.nat.id
  tags = merge(var.tags, { Name = "${var.name}-nat" })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  route { cidr_block = "0.0.0.0/0" nat_gateway_id = aws_nat_gateway.nat.id }
  tags = merge(var.tags, { Name = "${var.name}-private-rt" })
}
resource "aws_route_table_association" "private" {
  count = var.az_count
  subnet_id = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

output "vpc_id" { value = aws_vpc.this.id }
output "public_subnet_ids" { value = [for s in aws_subnet.public : s.id] }
output "private_subnet_ids" { value = [for s in aws_subnet.private : s.id] }
