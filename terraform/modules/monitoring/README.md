# Monitoring Module

Wires up CloudWatch alarms, a log group, and an SNS topic for notifications.

## Why this layout

**Three alarms, each answering a different question:**
- **High CPU** — "should this be scaling?" (operational, expected to fire occasionally)
- **ALB 5xx errors** — "is the application itself broken?" (application-level failure)
- **No healthy hosts** — "is the site completely down?" (critical, page-someone severity)

Three targeted alarms are more useful — and easier to explain in an
interview — than one catch-all alarm that doesn't tell you what's wrong.

**SNS with an optional email subscription.** The topic is always created so
alarms have somewhere to send notifications, but the email subscription
only gets created if `alarm_email` is set. This means `terraform apply`
doesn't fail or require a real inbox just to stand the environment up.

**14-day log retention.** CloudWatch Logs default to "never expire," which
quietly costs money forever. 14 days is enough to debug recent issues
without the retention cost of an indefinite log group — a deliberate,
explainable choice rather than an accident.

## Resources created

| Resource | Purpose |
|---|---|
| `aws_sns_topic` | Destination for alarm notifications |
| `aws_sns_topic_subscription` | Optional email subscription |
| `aws_cloudwatch_log_group` | Application log storage (14-day retention) |
| `aws_cloudwatch_metric_alarm` (x3) | High CPU, ALB 5xx, no healthy hosts |
