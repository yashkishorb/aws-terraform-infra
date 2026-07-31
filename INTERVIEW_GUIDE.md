# Interview Guide — Production-Ready AWS Infrastructure Automation

This document is prep material, not something to hand to an interviewer.
Read it, understand the *why* behind each answer, and be ready to explain
it in your own words and adapt it if they push back or ask "what if...".

---

## 1. How to describe the project in 30 seconds

> "I built a Terraform project that provisions a small production-style
> AWS environment — a VPC with public and private subnets, an Auto Scaling
> Group of EC2 instances behind an Application Load Balancer, CloudWatch
> monitoring with alarms, and a GitHub Actions pipeline that plans changes
> automatically and requires manual approval before applying. The
> Terraform code is split into reusable modules — networking, security,
> compute, monitoring — so the same modules deploy both a dev and a prod
> environment with different sizing. The main focus was applying real
> security practices: no SSH anywhere, IAM roles instead of access keys,
> and least-privilege security groups."

---

## 2. Why each AWS service is used

| Service | Why it's here |
|---|---|
| **VPC** | Isolated network boundary for the whole project; everything else lives inside it. |
| **Public subnets** | Only place anything internet-facing (the ALB) lives. |
| **Private subnets** | Where the EC2 instances run — no direct route from the internet. |
| **Internet Gateway** | Gives the public subnets (and, indirectly via NAT, the private subnets) a path to the internet. |
| **NAT Gateway** | Lets private instances reach the internet outbound (OS updates, SSM agent, package installs) without being reachable inbound. |
| **Route Tables** | Define which subnet's traffic goes where — public subnets route `0.0.0.0/0` to the IGW, private subnets route it to the NAT Gateway. |
| **Security Groups** | Stateful firewalls; the ALB SG allows public HTTP, the EC2 SG only allows traffic from the ALB SG — nothing else. |
| **EC2** | Runs the application. |
| **Launch Template** | Defines exactly how each instance in the ASG launches (AMI, instance type, security group, IAM profile, user data). Used instead of the older Launch Configuration because it supports versioning and newer EC2 features (like enforcing IMDSv2). |
| **Auto Scaling Group** | Keeps the desired number of healthy instances running across AZs, replaces unhealthy ones automatically, and scales based on load. |
| **Application Load Balancer** | Distributes incoming traffic across instances, health-checks them, and is the only internet-facing compute-adjacent resource. |
| **IAM Roles** | Let EC2 instances (and the CI pipeline) authenticate to AWS without storing long-lived access keys anywhere. |
| **CloudWatch** | Collects metrics/logs and triggers alarms — how you'd actually know if something's wrong. |
| **S3 (backend)** | Stores Terraform state remotely so it's shared, encrypted, and versioned instead of sitting on one person's laptop. |
| **DynamoDB (state locking)** | Prevents two `terraform apply` runs from happening at the same time and corrupting state. |

**If asked "why didn't you use X" (EKS, ECS, Transit Gateway, Terragrunt, etc.):**
> "The project is intentionally scoped to what a single application in a
> single environment actually needs. Adding a container orchestrator or a
> multi-account setup would add complexity without a real problem it's
> solving here — I wanted every resource in the project to have a clear,
> explainable purpose rather than checking off tool names."

---

## 3. Terraform concepts to be ready to explain

**Why modules?**
Modules let you reuse the same networking/security/compute code for both
`dev` and `prod` instead of duplicating `.tf` files. Each module takes
inputs (`variables.tf`) and exposes outputs (`outputs.tf`) so environments
can wire them together without knowing their internals.

**State and why it matters**
Terraform state is the file that maps your `.tf` resources to real AWS
resource IDs. Without it, Terraform wouldn't know what it already created.
Storing it remotely in S3 means it's not on one laptop, and enabling
encryption + versioning protects it. DynamoDB provides locking so
concurrent applies can't corrupt it.

**`terraform plan` vs `apply`**
`plan` shows what *would* change without changing anything — it's the
safety check. `apply` executes those changes. The CI pipeline always runs
`plan` on every PR, and only runs `apply` after a human approves.

**Why `-auto-approve` in CI but not run manually?**
Because the CI pipeline already gates `apply` behind a required reviewer
on the GitHub Environment — the human approval happens at the "allow this
job to run" step, not by re-confirming Terraform's own prompt.

**Why `.tfvars` files and not hardcoded values?**
Keeps environment-specific config (instance sizes, CIDR ranges) out of the
module code so the same module can produce different-sized environments.
`terraform.tfvars` is gitignored because it can contain values you don't
want in version control (though nothing here is a literal secret — this
project keeps real secrets, like the alarm email, optional/blank by
default).

**Why separate state files per environment?**
So a mistake in `dev` — a bad `terraform apply`, a typo, an accidental
`destroy` — can never touch `prod`'s state or resources.

**What's the difference between a resource and a data source?**
A `resource` block tells Terraform to create/manage something. A `data`
block reads information about something that already exists — this
project uses `data "aws_ami"` to always fetch the latest Amazon Linux 2023
AMI ID rather than hardcoding one that would go stale.

**What does `for_each`/`count` do here?**
`count` is used to create one subnet, one route table association, etc.
per AZ from a list of CIDRs — so adding a third AZ is a one-line change to
a variable, not new resource blocks.

---

## 4. Networking concepts

**Explain the traffic path from a user's browser to the app.**
1. User requests the ALB's DNS name.
2. DNS resolves to the ALB (spread across public subnets in 2 AZs).
3. The ALB's security group allows port 80 from anywhere.
4. The ALB forwards to a healthy target in the target group — an EC2
   instance in a private subnet.
5. The EC2 instance's security group only accepts traffic from the ALB's
   security group, on the app port.
6. The instance serves the response, which flows back through the ALB to
   the user.

**Why public vs private subnets, concretely?**
A subnet is "public" only because its route table sends `0.0.0.0/0` to an
Internet Gateway. "Private" subnets route `0.0.0.0/0` to a NAT Gateway
instead — so they can *initiate* outbound connections but nothing on the
internet can *initiate* an inbound connection to them.

**What does the NAT Gateway actually do, and why is it in the public subnet?**
It lets instances in private subnets make outbound connections (e.g. to
download OS patches) while still preventing any inbound connection from
the internet. It has to live in a public subnet because it needs its own
route to the Internet Gateway.

**Security Group vs Network ACL — did you use NACLs?**
No — this project relies on Security Groups, which are stateful (return
traffic is automatically allowed) and attached to resources, not subnets.
NACLs are stateless and subnet-level; they're normally an *additional*
layer of defense in more security-sensitive environments, not a
replacement for well-scoped security groups. Left out here to avoid
complexity without a specific threat they're mitigating.

**CIDR math — can you explain `/24` vs `/16`?**
The VPC uses a `/16` (65,536 addresses) so there's plenty of room to carve
out subnets. Each subnet uses a `/24` (256 addresses, ~251 usable after
AWS reserves 5) — small individually, but there are 4 of them (2 public, 2
private) plus room to add more without re-architecting.

---

## 5. Security concepts

**Why no SSH?**
SSH means an open port 22, a key pair to manage/rotate/leak, and (if
naively set up) a security group rule allowing some CIDR range in. SSM
Session Manager needs none of that — it uses the instance's IAM role over
an outbound HTTPS connection, is fully logged in CloudTrail, and doesn't
require any inbound port at all.

**IAM roles vs access keys — why does it matter?**
Access keys are long-lived credentials that can be committed to a repo,
leaked, or forgotten about. An IAM role provides short-lived, automatically
rotated credentials scoped to exactly what's attached — nothing to store,
leak, or manually rotate.

**What's least privilege here, concretely?**
The EC2 role has exactly two managed policies attached — SSM Core and
CloudWatch Agent — not `AdministratorAccess` and not a wildcard policy.
The EC2 security group allows traffic from the ALB security group only, on
one port, not from `0.0.0.0/0`.

**How does the CI pipeline authenticate to AWS?**
Via OIDC federation (`aws-actions/configure-aws-credentials` with
`role-to-assume`) — GitHub Actions requests short-lived credentials by
assuming an IAM role, instead of the repo storing a static
`AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` as a GitHub secret.

**What's IMDSv2 and why enforce it?**
The EC2 instance metadata service (IMDS) is how an instance can ask AWS
"what IAM role am I" and get temporary credentials. IMDSv1 doesn't require
a session token, which made it a target for SSRF-based credential theft
(an attacker tricks the app into making a request to the metadata
endpoint). IMDSv2 requires a token from a PUT request first, which closes
that class of vulnerability. It's enforced here via
`http_tokens = "required"` on the launch template.

---

## 6. Common troubleshooting scenarios (be ready to talk through these)

**"Your ALB shows 502/503 errors — how do you debug it?"**
1. Check the target group's health check status in the console/CLI — are
   targets healthy?
2. If unhealthy, check the health check path (`/health`) is actually
   returning 200 from the instance.
3. Check the EC2 security group allows traffic from the ALB security group
   on the right port.
4. Check the instance itself — via SSM Session Manager, not SSH — to see
   if the web server (httpd) is actually running (`systemctl status httpd`).
5. Check CloudWatch Logs / the user-data script output
   (`/var/log/cloud-init-output.log`) for bootstrap failures.

**"Your `terraform apply` is failing with a state lock error — what do you do?"**
It usually means another apply is still running, or a previous one
crashed without releasing the DynamoDB lock. Check if another run is
actually in progress first; if it's a stale lock, `terraform force-unlock
<lock-id>` clears it — but only after confirming nothing else is really
applying.

**"An instance keeps getting terminated and replaced — why?"**
Most likely the ASG's health check (`health_check_type = "ELB"`) is
marking it unhealthy because it's failing the ALB's health check, not
because of an EC2-level status check. Check the target group health check
settings and confirm the app is actually listening and responding on
`/health` within the configured timeout.

**"How would you roll out a change without downtime?"**
Update the Launch Template (new AMI or user data), which creates a new
version. The ASG doesn't automatically replace running instances on a new
Launch Template version by default — you'd trigger an instance refresh
(`aws autoscaling start-instance-refresh`) so the ASG replaces instances
gradually while keeping the minimum healthy count in the target group.

**"How do you know if the environment is healthy right now, without logging in?"**
CloudWatch: the `no_healthy_hosts` alarm would already be firing (paged
via SNS) if the ALB has zero healthy targets. The `high_cpu` alarm signals
sustained load. The ALB's own console dashboard shows request count,
target response time, and 5xx rate.

---

## 7. Design decisions you should be ready to defend

| Decision | Reasoning you can give |
|---|---|
| One shared NAT Gateway in dev, one per AZ in prod | Cost vs resilience trade-off — NAT Gateways are billed hourly + per GB; not worth doubling the cost in a throwaway dev environment, but a single point of failure isn't acceptable in prod. |
| No HTTPS/ACM in this version | Kept the scope to the compute/networking/IaC pattern rather than DNS + certificate management; listed explicitly as a "Future Improvement" rather than skipped silently. |
| `t3.micro` in dev / `t3.small` in prod | Right-size for cost in a portfolio/demo environment vs. giving prod a bit more headroom. |
| Target-tracking scaling (CPU) instead of step scaling | Simpler to reason about and tune (one target value) and is AWS's recommended default for straightforward "scale on one metric" cases. |
| 14-day CloudWatch log retention | Avoids unbounded storage cost from the default "never expire" setting while keeping enough history to debug recent issues. |
| Manual approval gate via GitHub Environments, not a separate approval tool | GitHub Environments' required-reviewer feature does exactly this natively, without adding another tool/service to the pipeline. |

---

## 8. Questions to ask them back (shows engagement, not just answering)

- "How do you handle Terraform state and environment separation on your team?"
- "Do you use manual approval gates for infrastructure changes, or is
  everything auto-applied?"
- "What does your on-call/alerting setup look like beyond CloudWatch —
  PagerDuty, Opsgenie, something else?"
- "How do you manage secrets in your Terraform/CI pipeline?"
