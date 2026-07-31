# Networking Module

Builds the VPC foundation: a 2-AZ VPC with public and private subnets, an
Internet Gateway, NAT Gateway(s), and the route tables that tie them together.

## Why this layout

**Public + private subnet split.** Only the Application Load Balancer sits in
the public subnets. Every EC2 instance sits in the private subnets, with no
route to the internet except outbound through NAT. This is the standard
"nothing but the load balancer is internet-facing" pattern used in almost
every real AWS architecture.

**Two Availability Zones.** A single-AZ setup would work, but it isn't
realistic — if that AZ has an issue, the app goes down. Spreading subnets
across two AZs lets the ALB and ASG survive the loss of one AZ.

**`single_nat_gateway` toggle.** NAT Gateways are billed per hour plus data
processed, and they're usually the most expensive line item in a small
Terraform demo environment. For `dev`, `single_nat_gateway = true` keeps
costs down — one NAT Gateway shared by both private subnets. For `prod`,
`single_nat_gateway = false` gives each AZ its own NAT Gateway so an AZ
failure doesn't take out egress for every private subnet. This mirrors a
real cost-vs-resilience trade-off teams actually make.

**No Transit Gateway / multiple VPCs.** This project has a single
application in a single VPC, so a Transit Gateway or VPC peering would be
complexity with nothing to connect to. Left out on purpose.

## Resources created

| Resource | Purpose |
|---|---|
| `aws_vpc` | Isolated network for the project |
| `aws_internet_gateway` | Gives public subnets a path to/from the internet |
| `aws_subnet` (public) | Hosts the ALB |
| `aws_subnet` (private) | Hosts EC2 instances |
| `aws_eip` + `aws_nat_gateway` | Gives private instances outbound internet access |
| `aws_route_table` (public) | Routes `0.0.0.0/0` to the IGW |
| `aws_route_table` (private) | Routes `0.0.0.0/0` to the NAT Gateway |

## Inputs / Outputs

See `variables.tf` and `outputs.tf`. Outputs (`vpc_id`, `public_subnet_ids`,
`private_subnet_ids`, etc.) are consumed by the `security` and `compute`
modules.
