resource "aws_ecs_cluster" "challenge" {
  name = "challenge-Cluster"
}

resource "aws_ecs_task_definition" "nginx" {
  family                   = "nginx-site"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024

  container_definitions = <<DEFINITION
[
  {
    "cpu": 512,
    "image": "nginx",
    "memory": 1024,
    "name": "nginx-site",
    "networkMode": "awsvpc",
    "requiresCompabilities": "FARGATE",
    "portMappings": [
      {
        "containerPort": 80,
        "hostPort": 80
      }
    ]
  }
]
DEFINITION
}

resource "aws_ecs_service" "nginx-site" {
  name            = "ecs-nginx"
  cluster         = "${aws_ecs_cluster.challenge.id}"
  task_definition = "${aws_ecs_task_definition.nginx.arn}"
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    security_groups = ["${aws_security_group.fargate_tasks.id}"]
    subnets         = ["${aws_subnet.subnet1.id}"]
  }

  load_balancer {
    target_group_arn = "${aws_alb_target_group.tg-nginx.arn}"
    container_name   = "nginx-site"
    container_port   = 80
  }

  depends_on = [
    "aws_alb_listener.nginx-site",
  ]
}

# ALB Security group
resource "aws_security_group" "ALB" {
  name        = "SG-ecs-alb"
  description = "controls access to the ALB"
  vpc_id      = "${aws_vpc.VPC_Terraform.id}"

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Traffic to the ECS Cluster should only come from the ALB
resource "aws_security_group" "fargate_tasks" {
  name        = "SG-fargate"
  description = "allow inbound access from the ALB only"
  vpc_id      = "${aws_vpc.VPC_Terraform.id}"

  ingress {
    protocol        = "tcp"
    from_port       = 80
    to_port         = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_alb" "nginx-fargate" {
  name            = "alb-nginx"
  subnets         = ["${aws_subnet.subnet.id}", "${aws_subnet.subnet1.id}"]
  security_groups = ["${aws_security_group.ALB.id}"]
}

resource "aws_alb_target_group" "tg-nginx" {
  name        = "tg-fargate-nginx"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = "${aws_vpc.VPC_Terraform.id}"
  target_type = "ip"
}

# Redirect all traffic from the ALB to the target group
resource "aws_alb_listener" "nginx-site" {
  load_balancer_arn = "${aws_alb.nginx-fargate.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_alb_target_group.tg-nginx.id}"
    type             = "forward"
  }
}

resource "aws_appautoscaling_target" "nginx" {
  service_namespace  = "ecs"
  resource_id        = "service/${aws_ecs_cluster.challenge.name}/${aws_ecs_service.nginx-site.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  min_capacity       = 1
  max_capacity       = 4
}

resource "aws_appautoscaling_policy" "nginx-up" {
  name                    = "nginx_scale_up"
  service_namespace       = "ecs"
  resource_id             = "service/${aws_ecs_cluster.challenge.name}/${aws_ecs_service.nginx-site.name}"
  scalable_dimension      = "ecs:service:DesiredCount"


  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment = 1
    }
  }

  depends_on = ["aws_appautoscaling_target.nginx"]
}

resource "aws_appautoscaling_policy" "nginx-down" {
  name                    = "nginx_scale_down"
  service_namespace       = "ecs"
  resource_id             = "service/${aws_ecs_cluster.challenge.name}/${aws_ecs_service.nginx-site.name}"
  scalable_dimension      = "ecs:service:DesiredCount"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 60
    metric_aggregation_type = "Maximum"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment = -1
    }
  }

  depends_on = ["aws_appautoscaling_target.nginx"]
}

/* metric used for auto scale */
resource "aws_cloudwatch_metric_alarm" "memory_half" {
  alarm_name          = "fargate_nginx_memory_utilization_high"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "50"

  dimensions {
    ClusterName = "${aws_ecs_cluster.challenge.name}"
    ServiceName = "${aws_ecs_service.nginx-site.name}"
  }

  alarm_actions = ["${aws_appautoscaling_policy.nginx-up.arn}"]
  ok_actions    = ["${aws_appautoscaling_policy.nginx-down.arn}"]
}
