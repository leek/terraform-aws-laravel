# ============================================================================
# AWS End User Messaging SMS — inbound + delivery event wiring
# ============================================================================
#
# Provisions the AWS-side infrastructure for an application to receive inbound
# SMS replies and delivery receipts from AWS End User Messaging SMS (formerly
# Pinpoint SMS Voice v2).
#
# Architecture:
#
#   AWS End User Messaging  ──┐
#   (origination phone) ──────┤
#                             │ 1. Two-way SMS routes inbound to SNS topic
#                             │ 2. Configuration set event destination
#                             │    routes delivery events to SNS topic
#                             ▼
#                       SNS topic (this module)
#                             │
#                             │ HTTPS subscription
#                             ▼
#               https://{domain}{webhook_path}
#
# The application's controller must verify the SNS signature, auto-confirm
# subscriptions, and dispatch inbound messages + delivery events.
#
# Two TF gaps the AWS provider doesn't fill (handled via aws cli null_resource):
#   - aws_pinpointsmsvoicev2_configuration_set_event_destination does not exist
#   - Attaching an SNS topic to an existing phone number's two-way config
#     requires importing the phone number resource; we keep the existing number
#     unmanaged and update it via aws cli for ergonomics
# ============================================================================

locals {
  webhook_url            = "https://${var.domain_name}${var.webhook_path}"
  name_prefix            = "${var.app_name}-${var.environment}"
  event_destination_name = "sns-events"
}

# ----------------------------------------------------------------------------
# SNS topic — receives both inbound messages and delivery events
# ----------------------------------------------------------------------------

resource "aws_sns_topic" "events" {
  name              = "${local.name_prefix}-sms-events"
  kms_master_key_id = var.sns_kms_key_id

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-sms-events"
  })
}

resource "aws_sns_topic_policy" "events" {
  arn    = aws_sns_topic.events.arn
  policy = data.aws_iam_policy_document.events_topic_policy.json
}

data "aws_iam_policy_document" "events_topic_policy" {
  statement {
    sid    = "AllowEndUserMessagingPublish"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["sms-voice.amazonaws.com"]
    }

    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.events.arn]

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.caller_identity_account_id]
    }
  }
}

# ----------------------------------------------------------------------------
# HTTPS subscription — endpoint_auto_confirms relies on application code GET'ing
# the SubscribeURL contained in the SubscriptionConfirmation payload
# ----------------------------------------------------------------------------

resource "aws_sns_topic_subscription" "events_webhook" {
  topic_arn                       = aws_sns_topic.events.arn
  protocol                        = "https"
  endpoint                        = local.webhook_url
  endpoint_auto_confirms          = true
  confirmation_timeout_in_minutes = var.subscription_confirmation_timeout_minutes
  raw_message_delivery            = false
}

# ----------------------------------------------------------------------------
# IAM role assumed by sms-voice.amazonaws.com to publish to the SNS topic
# (required by aws_pinpointsmsvoicev2_phone_number two_way_channel_role)
# ----------------------------------------------------------------------------

resource "aws_iam_role" "two_way_channel" {
  name               = "${local.name_prefix}-sms-two-way-channel"
  assume_role_policy = data.aws_iam_policy_document.two_way_channel_assume.json

  tags = merge(var.common_tags, {
    Name = "${local.name_prefix}-sms-two-way-channel"
  })
}

data "aws_iam_policy_document" "two_way_channel_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["sms-voice.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [var.caller_identity_account_id]
    }
  }
}

resource "aws_iam_role_policy" "two_way_channel" {
  name   = "${local.name_prefix}-sms-two-way-channel"
  role   = aws_iam_role.two_way_channel.id
  policy = data.aws_iam_policy_document.two_way_channel_publish.json
}

data "aws_iam_policy_document" "two_way_channel_publish" {
  statement {
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [aws_sns_topic.events.arn]
  }
}

# ----------------------------------------------------------------------------
# Configuration set — name is exposed as AWS_SMS_CONFIGURATION_SET env var
# ----------------------------------------------------------------------------

resource "aws_pinpointsmsvoicev2_configuration_set" "this" {
  name                 = var.configuration_set_name
  default_message_type = var.default_message_type

  tags = merge(var.common_tags, {
    Name = var.configuration_set_name
  })
}

# ----------------------------------------------------------------------------
# Configuration set event destination — pipes delivery events into the SNS
# topic. AWS provider has no resource for this, so we drive it via aws cli.
# Triggers re-create when the topic ARN, config set, or role changes.
# ----------------------------------------------------------------------------

resource "null_resource" "event_destination" {
  triggers = {
    configuration_set = aws_pinpointsmsvoicev2_configuration_set.this.name
    sns_topic_arn     = aws_sns_topic.events.arn
    role_arn          = aws_iam_role.two_way_channel.arn
    region            = var.aws_region
    destination_name  = local.event_destination_name
  }

  provisioner "local-exec" {
    when    = create
    command = <<-EOT
      set -euo pipefail

      aws pinpoint-sms-voice-v2 delete-event-destination \
        --region "${self.triggers.region}" \
        --configuration-set-name "${self.triggers.configuration_set}" \
        --event-destination-name "${self.triggers.destination_name}" \
        2>/dev/null || true

      aws pinpoint-sms-voice-v2 create-event-destination \
        --region "${self.triggers.region}" \
        --configuration-set-name "${self.triggers.configuration_set}" \
        --event-destination-name "${self.triggers.destination_name}" \
        --matching-event-types \
          TEXT_ALL \
        --sns-destination "TopicArn=${self.triggers.sns_topic_arn}"
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      aws pinpoint-sms-voice-v2 delete-event-destination \
        --region "${self.triggers.region}" \
        --configuration-set-name "${self.triggers.configuration_set}" \
        --event-destination-name "${self.triggers.destination_name}" \
        2>/dev/null || true
    EOT
  }

  depends_on = [
    aws_pinpointsmsvoicev2_configuration_set.this,
    aws_sns_topic_policy.events,
  ]
}

# ----------------------------------------------------------------------------
# Two-way SMS attachment to existing phone number
#
# Skipped if phone_number_id is empty. Otherwise updates the phone number to
# enable two-way SMS pointing at the SNS topic + IAM role. Re-runs whenever
# any of the inputs change.
# ----------------------------------------------------------------------------

resource "null_resource" "attach_phone_number_two_way" {
  count = var.phone_number_id != "" ? 1 : 0

  triggers = {
    phone_number_id = var.phone_number_id
    sns_topic_arn   = aws_sns_topic.events.arn
    role_arn        = aws_iam_role.two_way_channel.arn
    region          = var.aws_region
  }

  provisioner "local-exec" {
    when    = create
    command = <<-EOT
      set -euo pipefail

      # IAM eventual consistency — the role may not be assumable for a few
      # seconds after creation. Retry up to 30s before giving up.
      for i in 1 2 3 4 5 6; do
        aws pinpoint-sms-voice-v2 update-phone-number \
          --region "${self.triggers.region}" \
          --phone-number-id "${self.triggers.phone_number_id}" \
          --two-way-enabled \
          --two-way-channel-arn "${self.triggers.sns_topic_arn}" \
          --two-way-channel-role "${self.triggers.role_arn}" \
          && exit 0
        echo "IAM role not yet propagated, retrying in 5s... (attempt $i/6)"
        sleep 5
      done
      exit 1
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      aws pinpoint-sms-voice-v2 update-phone-number \
        --region "${self.triggers.region}" \
        --phone-number-id "${self.triggers.phone_number_id}" \
        --no-two-way-enabled \
        2>/dev/null || true
    EOT
  }

  depends_on = [
    aws_iam_role_policy.two_way_channel,
    aws_sns_topic_policy.events,
  ]
}
