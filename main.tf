##################### VPC ###############

resource "aws_vpc" "test" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "Test"
  }
}

resource "aws_internet_gateway" "testig" {
  vpc_id = aws_vpc.test.id
  
  tags = {
    Name = "TestIg"
  }
  
}

resource "aws_route_table" "private" {
  count = length(var.private_subnet_cidr_blocks)

  vpc_id = aws_vpc.test.id
   
  tags = {
    Name = "PrivateRouteTable"
  }
}

resource "aws_route" "private" {
  count = length(var.private_subnet_cidr_blocks)

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.default[count.index].id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.test.id
  
  tags = {
    Name = "PublicRouteTable"
  }

}

resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.testig.id
}

resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidr_blocks)

  vpc_id            = aws_vpc.test.id
  cidr_block        = var.private_subnet_cidr_blocks[count.index]
  availability_zone = var.availability_zones[count.index]
  
  tags = {
    Name = "PrivateSubnet"
  }

}

resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidr_blocks)

  vpc_id                  = aws_vpc.test.id
  cidr_block              = var.public_subnet_cidr_blocks[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true
  
  tags = {
    Name = "PublicSubnet"
  }
 
}

resource "aws_route_table_association" "private" {
  count = length(var.private_subnet_cidr_blocks)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidr_blocks)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}


# NAT resources

resource "aws_eip" "nat" {
  count = length(var.public_subnet_cidr_blocks)

  vpc = true
}

resource "aws_nat_gateway" "default" {
  depends_on = [aws_internet_gateway.testig]

  count = length(var.public_subnet_cidr_blocks)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  
  tags = {
    Name = "NatGateway"
  }
  
}

#####Security Group ##########

resource "aws_security_group" "main" {
  name = var.sec-grp_name
  vpc_id = aws_vpc.test.id

  ingress {
  protocol = "tcp"
  from_port = 22
  to_port = 22
  cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
  protocol = "tcp"
  from_port = 80
  to_port = 80
  cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
  protocol = "tcp"
  from_port = 8080
  to_port = 8080
  cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
  protocol = "-1"
  from_port = 0
  to_port = 0
  cidr_blocks = ["0.0.0.0/0"]
  }

   tags = {
        Name = "${var.environment}-ALBSecurityGroup"
    }
}


#############ALB#############################

resource "aws_lb" "this" {
  count              = var.create_lb ? 1 : 0
  name               = "${var.alb_name}-${var.environment}"
  load_balancer_type = var.load_balancer_type
  internal           = var.internal
  security_groups    = aws_security_group.main.*.id
  subnets            = aws_subnet.public[*].id
  idle_timeout                     = var.idle_timeout
  enable_cross_zone_load_balancing = var.enable_cross_zone_load_balancing
  enable_deletion_protection       = var.enable_deletion_protection
  enable_http2                     = var.enable_http2
  ip_address_type                  = var.ip_address_type
  drop_invalid_header_fields       = var.drop_invalid_header_fields
  tags = {
    Environment = var.environment
    Name = "${var.environment}-ALB"
  }
}

resource "aws_lb_target_group" "main" {
  count = var.create_lb ? length(var.target_groups) : 0
  name        = lookup(var.target_groups[count.index], "name", null)
  vpc_id      = aws_vpc.test.id
  port        = lookup(var.target_groups[count.index], "backend_port", null)
  protocol    = lookup(var.target_groups[count.index], "backend_protocol", null) != null ? upper(lookup(var.target_groups[count.index], "backend_protocol")) : null
  target_type = lookup(var.target_groups[count.index], "target_type", null)
  deregistration_delay    = lookup(var.target_groups[count.index], "deregistration_delay", 300)
  dynamic "health_check" {
    for_each = length(keys(lookup(var.target_groups[count.index], "health_check", {}))) == 0 ? [] : [lookup(var.target_groups[count.index], "health_check", {})]

    content {
      enabled             = lookup(health_check.value, "enabled", null)
      interval            = lookup(health_check.value, "interval", null)
      path                = lookup(health_check.value, "path", null)
      port                = lookup(health_check.value, "port", null)
      healthy_threshold   = lookup(health_check.value, "healthy_threshold", null)
      unhealthy_threshold = lookup(health_check.value, "unhealthy_threshold", null)
      timeout             = lookup(health_check.value, "timeout", null)
      protocol            = lookup(health_check.value, "protocol", null)
      matcher             = lookup(health_check.value, "matcher", null)
    }
  }
  tags = {
    Environment = var.environment
    Name = "${var.environment}-TargetGroup"
  }
  depends_on = [aws_lb.this]
}

resource "aws_lb_listener" "frontend_http_tcp" {
  count = var.create_lb ? length(var.http_tcp_listeners) : 0
  load_balancer_arn = aws_lb.this[0].arn
  port     = var.http_tcp_listeners[count.index]["port"]
  protocol = var.http_tcp_listeners[count.index]["protocol"]

  dynamic "default_action" {
    for_each = length(keys(var.http_tcp_listeners[count.index])) == 0 ? [] : [var.http_tcp_listeners[count.index]]

    # Defaults to forward action if action_type not specified
    content {
      type             = lookup(default_action.value, "action_type", "forward")
      target_group_arn = contains([null, "", "forward"], lookup(default_action.value, "action_type", "")) ? aws_lb_target_group.main[lookup(default_action.value, "target_group_index", count.index)].id : null

      dynamic "redirect" {
        for_each = length(keys(lookup(default_action.value, "redirect", {}))) == 0 ? [] : [lookup(default_action.value, "redirect", {})]

        content {
          path        = lookup(redirect.value, "path", null)
          host        = lookup(redirect.value, "host", null)
          port        = lookup(redirect.value, "port", null)
          protocol    = lookup(redirect.value, "protocol", null)
          query       = lookup(redirect.value, "query", null)
          status_code = redirect.value["status_code"]
        }
      }
  }
}

}

resource "aws_lb_listener_rule" "path_pattern" {
  count = var.create_lb ? length(var.http_tcp_listener_rule) : 0
  listener_arn = aws_lb_listener.frontend_http_tcp[0].arn
  dynamic "action" {
      for_each = length(keys(var.http_tcp_listener_rule[count.index])) == 0 ? [] : [var.http_tcp_listener_rule[count.index]]
    content {
        type             = lookup(action.value, "action_type", "forward")
        target_group_arn = contains([null, "", "forward"], lookup(action.value, "action_type", "")) ? aws_lb_target_group.main[lookup(action.value, "target_group_index", count.index)].id : null
    }
  }
   condition {
    path_pattern {
      values = lookup(var.http_tcp_listener_rule[count.index], "path_pattern", null)
    }
  }
}


############################EC2 #######################################

resource "aws_instance" "DevOps-test" {
  
  ami = var.ami
  count = var.count
  subnet_id  = aws_subnet.public.*[0].id
  instance_type = "t2.micro"
  security_groups = aws_security_group.main.*.id
  key_name = "kishore"
  #user_data     = "${file("env.sh")}"
  
  tags = {
      Name        = "Devops-Test"
    }

} 

resource "aws_lb_target_group_attachment" "test" {
  
  target_group_arn = aws_lb_target_group.main.*[0].arn
  target_id        = aws_instance.DevOps-test.*[0].id
  port             = 8080
}

resource "aws_lb_target_group_attachment" "test1" {
  
  target_group_arn = aws_lb_target_group.main.*[0].arn
  target_id        = aws_instance.DevOps-test.*[1].id
  port             = 8080
}





