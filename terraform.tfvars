tag 		= "Test"
########################### VPC ################
access_key = "AKIAQRHC4ESZHHKDIEQP"
secret_key = "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"
environment	= "Test"
region = "us-east-1"
name = "DevOpsTest"
project = "Test"
cidr_block  = "10.200.0.0/16"
public_subnet_cidr_blocks = ["10.200.1.0/24", "10.200.2.0/24"]
private_subnet_cidr_blocks = ["10.200.3.0/24", "10.200.4.0/24"]
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
sec-grp_name = "Test-sg"

##############ALB ####################

create_lb = true
alb_name = "Test-ALB"
load_balancer_type = "application"
internal		= false
target_groups = [
    {
      name                 = "ALB-TG"
      backend_protocol     = "HTTP"
      backend_port         = 8080
      target_type          = "instance"
      deregistration_delay = 60
      health_check = {
        enabled             = true
        interval            = 30
        path                = "/"
        port                = "traffic-port"
        healthy_threshold   = 3
        unhealthy_threshold = 2
        timeout             = 3
        protocol            = "HTTP"
        matcher             = "200-499"
      }
    }
 ]
 
http_tcp_listeners      = [
    {
        port            = 80
        protocol        = "HTTP"
        default_action  = {
            action_type = "forward"
        }
    },
]

http_tcp_listener_rule  = [
    {
        action        = {
          action_type = "forward"
        }
        path_pattern        = ["/*"]
    }
]

