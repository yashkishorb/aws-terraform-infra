# -----------------------------------------------------------------------------
# Security Group: Application Load Balancer
# Accepts HTTP from the internet. In a real deployment with a domain/ACM
# cert you'd add 443 and redirect 80 -> 443; kept to 80 here to stay focused
# on the infra pattern rather than DNS/certificate setup.
# -----------------------------------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.environment}-alb-sg"
  description = "Allow inbound HTTP from the internet"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-alb-sg"
  })
}

# -----------------------------------------------------------------------------
# Security Group: EC2 application instances
# Least privilege: only accepts traffic on the app port, and only from the
# ALB security group - not from any CIDR range. No port 22 rule exists at
# all; administrative access goes through SSM Session Manager instead.
# -----------------------------------------------------------------------------
resource "aws_security_group" "ec2" {
  name        = "${var.project_name}-${var.environment}-ec2-sg"
  description = "Allow inbound app traffic from the ALB only. No SSH."
  vpc_id      = var.vpc_id

  ingress {
    description     = "App traffic from ALB"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all outbound (patches, SSM, package installs via NAT)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-ec2-sg"
  })
}

# -----------------------------------------------------------------------------
# IAM Role for EC2 instances
# Uses an instance profile + IAM role instead of long-lived access keys.
# Attaches only the managed policies the instances actually need:
#   - SSM Core: enables Session Manager (no SSH keys, no open port 22)
#   - CloudWatch Agent: lets instances push custom metrics/logs
# -----------------------------------------------------------------------------
resource "aws_iam_role" "ec2" {
  name = "${var.project_name}-${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version            = "2012-10-17"
    Statement          = [
      {
        Effect    = "Allow"
        Principal = {
          Service   = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-ec2-role"
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project_name}-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2.name
}
