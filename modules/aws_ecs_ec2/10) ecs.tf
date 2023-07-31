resource "aws_ecs_cluster" "this" {
  name = "${var.deployment_name}-ecs"

  setting {
    name  = "containerInsights"
    value = var.ecs_insights_enabled
  }
}

data "aws_ami" "this" {
  most_recent = true # get the latest version
  name_regex = "^amzn2-ami-ecs-hvm-\\d\\.\\d\\.\\d{8}-x86_64-ebs$"

  filter {
    name = "virtualization-type"
    values = [
      "hvm"
    ]
  }

  owners = [
    "amazon" # only official images
  ]
}

resource "aws_launch_configuration" "this" {
  name_prefix   = "${var.deployment_name}-ecs-launch-configuration-"
  image_id      = data.aws_ami.this.id
  instance_type = var.instance_type # e.g. t2.medium
  spot_price    = var.spot_required_cost
  enable_monitoring           = true
  associate_public_ip_address = false

  # This user data represents a collection of “scripts” that will be executed the first time the machine starts.
  # This specific example makes sure the EC2 instance is automatically attached to the ECS cluster that we create earlier
  # and marks the instance as purchased through the Spot pricing
  user_data = <<-EOF
  #!/bin/bash
  echo ECS_CLUSTER=${var.deployment_name}-ecs >> /etc/ecs/ecs.config
  eco ECS_ENABLE_SPOT_INSTANCE_DRAINING=true
  EOF

  # We’ll see security groups later
  security_groups = [
    aws_security_group.ec2.id
  ]

  # If you want to SSH into the instance and manage it directly:
  # 1. Make sure this key exists in the AWS EC2 dashboard
  # 2. Make sure your local SSH agent has it loaded
  # 3. Make sure the EC2 instances are launched within a public subnet (are accessible from the internet)
  key_name = var.ssh_key_name

  # Allow the EC2 instances to access AWS resources on your behalf, using this instance profile and the permissions defined there
  iam_instance_profile = aws_iam_instance_profile.ec2.arn
  
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "this" {
  name                 = "${var.deployment_name}-autoscaling-group"
  max_size             = var.max_instance_count
  min_size             = var.min_instance_count
  desired_capacity     = var.min_instance_count
  vpc_zone_identifier  = var.subnet_ids
  launch_configuration = aws_launch_configuration.this.name

  default_cooldown          = 30
  health_check_grace_period = 30

  termination_policies = [
    "OldestInstance"
  ]

  tag {
    key                 = "AmazonECSManaged"
    value               = ""
    propagate_at_launch = true
  }

  tag {
    key                 = "project"
    value               = var.project
    propagate_at_launch = true
  }

  tag {
    key                 = "Cluster"
    value               = "${var.deployment_name}-ecs"
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "${var.deployment_name}-ec2-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Attach an autoscaling policy to the spot cluster to target 70% MemoryReservation on the ECS cluster.
resource "aws_autoscaling_policy" "this" {
  name                   = "${var.deployment_name}-ecs-scale-policy"
  policy_type            = "TargetTrackingScaling"
  adjustment_type        = "ChangeInCapacity"
  autoscaling_group_name = aws_autoscaling_group.this.name

  target_tracking_configuration {
    customized_metric_specification {
      metric_dimension {
        name  = "ClusterName"
        value = "${var.deployment_name}-ecs"
      }
      metric_name = "MemoryReservation"
      namespace   = "AWS/ECS"
      statistic   = "Average"
    }
    target_value = var.autoscaling_memory_reservation_target
  }
}

resource "aws_ecs_capacity_provider" "this" {
  name = "${var.deployment_name}-ecs-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.this.arn
  }
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "${var.deployment_name}-ecs-log-group"
  retention_in_days = var.log_retention_in_days
  tags = {project=var.project}
}

resource "aws_ecs_service" "retool" {
  name                               = "${var.deployment_name}-main-service"
  cluster                            = aws_ecs_cluster.this.id
  task_definition                    = aws_ecs_task_definition.retool.arn
  desired_count                      = var.min_instance_count -1
  deployment_maximum_percent         = var.maximum_percent
  deployment_minimum_healthy_percent = var.minimum_healthy_percent
  iam_role                           = aws_iam_role.service_role.arn

  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "retool"
    container_port   = 3000
  }
  tags = {project=var.project}
}

resource "aws_ecs_service" "jobs_runner" {
  name            = "${var.deployment_name}-jobs-runner-service"
  cluster         = aws_ecs_cluster.this.id
  desired_count   = 1
  task_definition = aws_ecs_task_definition.retool_jobs_runner.arn
  tags = {project=var.project}
}

resource "aws_ecs_task_definition" "retool_jobs_runner" {
  family        = "retool"
  task_role_arn = aws_iam_role.task_role.arn
  container_definitions = jsonencode(
    [
      {
        name      = "retool-jobs-runner"
        essential = true
        image     = var.ecs_retool_image
        cpu       = var.ecs_task_cpu
        memory    = var.ecs_task_memory
        command = [
          "./docker_scripts/start_api.sh"
        ]

        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = aws_cloudwatch_log_group.this.id
            awslogs-region        = var.aws_region
            awslogs-stream-prefix = "SERVICE_RETOOL"
          }
        }

        portMappings = [
          {
            containerPort = 3000
            hostPort      = 80
            protocol      = "tcp"
          }
        ]

        environment = concat(
          local.environment_variables,
          [
            {
              name  = "SERVICE_TYPE"
              value = "JOBS_RUNNER"
            }
          ]
        )
      }
    ]
  )
}
resource "aws_ecs_task_definition" "retool" {
  family        = "retool"
  task_role_arn = aws_iam_role.task_role.arn
  container_definitions = jsonencode(
    [
      {
        name      = "retool"
        essential = true
        image     = var.ecs_retool_image
        cpu       = var.ecs_task_cpu
        memory    = var.ecs_task_memory
        command = [
          "./docker_scripts/start_api.sh"
        ]

        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = aws_cloudwatch_log_group.this.id
            awslogs-region        = var.aws_region
            awslogs-stream-prefix = "SERVICE_RETOOL"
          }
        }

        portMappings = [
          {
            containerPort = 3000
            hostPort      = 80
            protocol      = "tcp"
          }
        ]

        environment = concat(
          local.environment_variables,
          [
            {
              name  = "SERVICE_TYPE"
              value = "MAIN_BACKEND,DB_CONNECTOR"
            },
            {
              "name"  = "COOKIE_INSECURE",
              "value" = tostring(var.cookie_insecure)
            }
          ]
        )
      }
    ]
  )
}