# CMDB on AWS (EKS + ALB + NGINX + RDS for SQL Server)

This bundle gives you:
- Terraform skeleton for VPC, EKS, RDS SQL Server, ECR, IAM (IRSA).
- Helm charts for `api`, `extsys1`, `extsys2`, and an ALB edge Ingress (aws-load-balancer-controller) that fronts the NGINX Ingress Controller.
- Kubernetes CronJob manifest for ingest.
- GitHub Actions sample workflow.

## Deploy order
1) Terraform: VPC, EKS, ECR, RDS, IAM.
2) Install aws-load-balancer-controller, ingress-nginx, external-dns, cert-manager.
3) Helm install app charts and edge ingress.
4) Configure DNS (Route53) to your ALB via external-dns or manual record.

## Quick Helm
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace -f helm/ingress-nginx/values.yaml
helm upgrade --install api     ./helm/api     -n cmdb --create-namespace
helm upgrade --install extsys1 ./helm/extsys1 -n cmdb
helm upgrade --install extsys2 ./helm/extsys2 -n cmdb
helm upgrade --install edge    ./helm/edge    -n ingress-nginx
