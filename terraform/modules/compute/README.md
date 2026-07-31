# Compute Module

Creates the Launch Template, Auto Scaling Group, and Application Load
Balancer that actually run and serve the application.

## Why this layout

**Launch Template, not Launch Configuration.** Launch Configurations are
the older AWS API and can't be updated in place — AWS itself recommends
Launch Templates for anything new. It also supports versioning (`$Latest`),
which is what lets the ASG pick up a new AMI/user-data change without
manually recreating anything.

**IMDSv2 enforced (`http_tokens = "required"`).** IMDSv1 is vulnerable to
SSRF-based credential theft; requiring token-based access to instance
metadata is an AWS-recommended hardening step that costs nothing to enable.

**No `key_name` on the launch template.** Consistent with the security
module: there's no SSH key pair because there's no SSH access. Instances
are managed through SSM Session Manager.

**Target tracking scaling on CPU (60%).** Simpler and more realistic for a
small web app than step scaling with manually-tuned CloudWatch alarms.
Target tracking is AWS's recommended default for "scale based on one
metric" use cases.

**Health check on `/health`, not `/`.** Using a dedicated lightweight
health endpoint instead of the homepage is standard practice — it avoids
coupling infrastructure health checks to application content changes.

**ALB in public subnets, ASG in private subnets.** This is the entire
point of the networking split from the `networking` module: the only thing
internet traffic ever touches directly is the load balancer.

## Resources created

| Resource | Purpose |
|---|---|
| `aws_launch_template` | Instance config: AMI, type, SG, IAM profile, user data |
| `aws_lb` | Public Application Load Balancer |
| `aws_lb_target_group` | Routes ALB traffic to healthy instances |
| `aws_lb_listener` | Listens on port 80, forwards to the target group |
| `aws_autoscaling_group` | Maintains desired instance count across AZs |
| `aws_autoscaling_policy` | Target-tracking scaling on average CPU |
