data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# -----------------------------------------------------------------------------
# Security group - SSH for administration, the Jenkins UI and VPC internal traffic
# -----------------------------------------------------------------------------

resource "aws_security_group" "server" {
  name_prefix = "${var.name_prefix}-jenkins-sg-"
  description = "Security group for the Jenkins server"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH administration"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  ingress {
    description = "Jenkins web interface"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = var.jenkins_ui_cidrs
  }

  ingress {
    description = "Traffic inside the VPC"
    from_port   = 0
    to_port     = 65535
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-jenkins-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# -----------------------------------------------------------------------------
# IAM role - SSM Session Manager gives shell access without an SSH key pair
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "server" {
  name               = "${var.name_prefix}-jenkins-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-jenkins-ec2-role"
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.server.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ecr_read" {
  role       = aws_iam_role.server.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "server" {
  name = "${var.name_prefix}-jenkins-ec2-profile"
  role = aws_iam_role.server.name

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-jenkins-ec2-profile"
  })
}

# -----------------------------------------------------------------------------
# EC2 instance running Jenkins
# -----------------------------------------------------------------------------

resource "aws_eip" "server" {
  count = var.assign_eip ? 1 : 0

  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-jenkins-eip"
  })
}

resource "aws_instance" "server" {
  ami                         = var.ami_id != "" ? var.ami_id : data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.server.id]
  iam_instance_profile        = aws_iam_instance_profile.server.name
  key_name                    = var.key_name != "" ? var.key_name : null
  associate_public_ip_address = var.assign_eip

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  user_data = var.user_data != "" ? var.user_data : null

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-jenkins-server"
    Role = "jenkins"
  })
}

resource "aws_eip_association" "server" {
  count = var.assign_eip ? 1 : 0

  instance_id   = aws_instance.server.id
  allocation_id = aws_eip.server[0].id
}
