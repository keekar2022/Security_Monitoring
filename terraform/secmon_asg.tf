# Concept: Mukesh Kesharwani
# Contact: mukesh.kesharwani@adobe.com

resource "aws_launch_template" "secmon" {
  lifecycle {
    precondition {
      condition     = local.secmon_ami_id_ok
      error_message = "AMI could not be resolved. Set secmon_ami_id or image_factory_amazon_linux_ami_us_east_1."
    }
    create_before_destroy = true
  }

  name_prefix   = "${var.project_name}-lt-"
  image_id      = local.secmon_ami_id
  instance_type = var.instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.secmon.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.secmon.name
  }

  user_data = base64encode(local.user_data)

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name              = "${var.project_name}-secmon"
      Stack             = var.project_name
      SECMON_SSM_TARGET = "true"
      Purpose           = "security-monitoring-dashboard"
    }
  }

  depends_on = [aws_iam_instance_profile.secmon]
}

resource "aws_autoscaling_group" "secmon" {
  name                      = "${var.project_name}-asg"
  vpc_zone_identifier       = aws_subnet.public[*].id
  desired_capacity          = var.asg_desired_capacity
  max_size                  = var.asg_max_size
  min_size                  = var.asg_min_size
  health_check_type         = "ELB"
  health_check_grace_period = var.asg_health_check_grace_period
  wait_for_capacity_timeout = "15m"
  force_delete              = true
  capacity_rebalance        = true

  launch_template {
    id      = aws_launch_template.secmon.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-asg"
    propagate_at_launch = false
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_capacity]
  }
}

resource "aws_autoscaling_attachment" "secmon" {
  autoscaling_group_name = aws_autoscaling_group.secmon.name
  lb_target_group_arn    = aws_lb_target_group.streamlit.arn
}
