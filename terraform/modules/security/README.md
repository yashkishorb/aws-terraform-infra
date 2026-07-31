# Security Module

Creates the two security groups and the IAM role/instance profile the
compute layer needs.

## Why this layout

**Two security groups, chained.** The ALB security group accepts HTTP
from `0.0.0.0/0` because that's its job — it's the public entry point. The
EC2 security group only accepts traffic **from the ALB's security group**,
not from any IP range. This means even if someone finds an instance's
private IP, they can't reach it directly; traffic has to come through the
load balancer. This is a standard least-privilege pattern, not something
specific to this project.

**No SSH / port 22 anywhere.** There's no ingress rule for port 22 on
purpose. Administrative access to instances goes through **AWS Systems
Manager Session Manager**, which needs no open inbound port, no bastion
host, and no SSH key pair to manage or leak. The trade-off is that it
requires the SSM agent (present by default on Amazon Linux 2/2023 AMIs)
and outbound internet access, which the NAT Gateway from the networking
module already provides.

**IAM role instead of access keys.** The EC2 instances assume an IAM role
via an instance profile rather than having AWS access keys stored anywhere.
Credentials are short-lived and automatically rotated by AWS — there's
nothing to leak in a repo or an AMI.

**Only two managed policies attached:**
- `AmazonSSMManagedInstanceCore` — enables Session Manager
- `CloudWatchAgentServerPolicy` — lets the instance push logs/metrics

No `AdministratorAccess`, no wildcard `*` actions. If the app later needs
to talk to another AWS service (e.g. S3), a scoped custom policy should be
added rather than widening these.

## Resources created

| Resource | Purpose |
|---|---|
| `aws_security_group.alb` | Public HTTP ingress for the load balancer |
| `aws_security_group.ec2` | App-port ingress restricted to the ALB SG only |
| `aws_iam_role.ec2` | Role assumed by EC2 instances |
| `aws_iam_instance_profile.ec2` | Attaches the role to launched instances |
