provider "aws" {
  region  = "us-east-2"

}
resource "aws_vpc" "learn_vpn_vpc" {
  cidr_block = "192.168.0.0/16"

  tags = {
    Name = "vpc"
  }
}

resource "aws_subnet" "learn_vpn_subnet" {
  vpc_id     = aws_vpc.learn_vpn_vpc.id
  cidr_block = "192.168.1.0/24"

  tags = {
    Name = "learn_vpn_subnet"
  }
}

resource "aws_internet_gateway" "learn_vpn_igw" {
  vpc_id = aws_vpc.learn_vpn_vpc.id

  tags = {
    Name = "internet_gateway"
  }
}

resource "aws_route_table" "learn_vpn_rt" {
  vpc_id = aws_vpc.learn_vpn_vpc.id

  tags = {
    Name = "route_table"
  }
}

resource "aws_route" "subnet_exit_route" {
  route_table_id         = aws_route_table.learn_vpn_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.learn_vpn_igw.id
}

resource "aws_route_table_association" "route_table_association" {
  subnet_id      = aws_subnet.learn_vpn_subnet.id
  route_table_id = aws_route_table.learn_vpn_rt.id
}

### SSH Security Group
resource "aws_security_group" "allow_ssh" {
  vpc_id = aws_vpc.learn_vpn_vpc.id

  ingress {
    from_port   = 0
    to_port     = 22
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "security_group_ssh"
  }
}

data "aws_ami" "latest-ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "template_file" "frontend_hashicups" {
  template = file("./scripts/frontend_hashicups.yaml")
}

resource "aws_key_pair" "deployer" {
  key_name   = "vpn-key"
  public_key = "ssh-rsa AAAA....."
}

resource "aws_instance" "learn_vpn_vm" {
  ami           = data.aws_ami.latest-ubuntu.id
  instance_type = "t2.micro"
  key_name = aws_key_pair.deployer.key_name


  vpc_security_group_ids      = [aws_security_group.allow_ssh.id]
  subnet_id                   = aws_subnet.learn_vpn_subnet.id
  associate_public_ip_address = true


  user_data = data.template_file.frontend_hashicups.rendered
}

### Outputs

output "aws_vm_public_ip" {
  value = aws_instance.learn_vpn_vm.public_ip
}

output "aws_vm_private_ip" {
  value = aws_instance.learn_vpn_vm.private_ip
}
