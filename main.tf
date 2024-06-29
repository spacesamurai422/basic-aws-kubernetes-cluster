terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = "us-west-2"
}

//Security Group
resource "aws_security_group" "my_group" {
  name = "my_group"
  description = "Default group"
  vpc_id = aws_vpc.my_vpc.id

    tags = {
    Name = "my_group"
  }
}

/*
resource "aws_vpc_security_group_ingress_rule" "my_group_ingress" {
  security_group_id = aws_security_group.my_group.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "ssh"
  to_port           = 22
}
 */

resource "aws_vpc_security_group_ingress_rule" "my_group_ingress" {
  security_group_id = aws_security_group.my_group.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

resource "aws_vpc_security_group_egress_rule" "my_group_egress" {
  security_group_id = aws_security_group.my_group.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

//Networking
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.134.0.0/16"

  tags = {
    Name = "my_vpc"
  }
}

resource "aws_subnet" "my_subnet" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.134.0.0/20"
  availability_zone = "us-west-2a"

  tags = {
    Name = "my_subnet"
  }
}

resource "aws_network_interface" "jumpbox" {
  subnet_id   = aws_subnet.my_subnet.id
  private_ips = ["10.134.12.15"]
  security_groups = [aws_security_group.my_group.id]

  tags = {
    Name = "jumpbox primary nw"
  }
}

resource "aws_network_interface" "server" {
  subnet_id   = aws_subnet.my_subnet.id
  private_ips = ["10.134.12.16"]
  security_groups = [aws_security_group.my_group.id]

  tags = {
    Name = "server primary nw"
  }
}

resource "aws_network_interface" "node-0" {
  subnet_id   = aws_subnet.my_subnet.id
  private_ips = ["10.134.12.17"]

  tags = {
    Name = "node-0 primary nw"
  }
}

resource "aws_network_interface" "node-1" {
  subnet_id   = aws_subnet.my_subnet.id
  private_ips = ["10.134.12.18"]

  tags = {
    Name = "node-1 primary nw"
  }
}

//Storage
/*
resource "aws_ebs_volume" "jumpbox_ebs" {
  availability_zone = "us-west-2a"
  size              = 10
}

resource "aws_ebs_volume" "server_ebs" {
  availability_zone = "us-west-2a"
  size              = 20
}

resource "aws_ebs_volume" "node-0_ebs" {
  availability_zone = "us-west-2a"
  size              = 20
}

resource "aws_ebs_volume" "node-1_ebs" {
  availability_zone = "us-west-2a"
  size              = 20
}

resource "aws_volume_attachment" "jumpbox_ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.jumpbox_ebs.id
  instance_id = aws_instance.jumpbox.id
}

resource "aws_volume_attachment" "server_ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.server_ebs.id
  instance_id = aws_instance.server.id
}

resource "aws_volume_attachment" "node-0_ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.node-0_ebs.id
  instance_id = aws_instance.node-0.id
}

resource "aws_volume_attachment" "node-1_ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.node-1_ebs.id
  instance_id = aws_instance.node-1.id
}
 */


//Instances

resource "aws_instance" "jumpbox" {
  ami           = "ami-07564a05443c48891"
  instance_type = "t4g.nano"
  key_name = "new"
  network_interface {
    network_interface_id = aws_network_interface.jumpbox.id
    device_index         = 0
  }
  associate_public_ip_address = true  # Automatically assign a public IP
  root_block_device {
    volume_size = 10
    volume_type = "gp3"
  }
  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get -y install wget curl vim openssl git
              git clone --depth 1 https://github.com/kelseyhightower/kubernetes-the-hard-way.git
              cd /root/kubernetes-the-hard-way
              echo "10.134.12.16 server.kubernetes.local server" >> /root/kubernetes-the-hard-way/machines.txt
              echo "10.134.12.17 node-0.kubernetes.local node-0 10.200.0.0/24" >> /root/kubernetes-the-hard-way/machines.txt
              echo "10.134.12.18 node-1.kubernetes.local node-1 10.200.1.0/24" >> /root/kubernetes-the-hard-way/machines.txt
              mkdir /root/kubernetes-the-hard-way/downloads
              wget -q --https-only --timestamping -P /root/kubernetes-the-hard-way/downloads -i /root/kubernetes-the-hard-way/downloads.txt
              chmod +x /root/kubernetes-the-hard-way/downloads/kubectl
              cp /root/kubernetes-the-hard-way/downloads/kubectl /usr/local/bin/
              git clone https://github.com/spacesamurai422/basic-aws-kubernetes-cluster.git
              nohup basic-aws-kubernetes-cluster/setup.sh > /root/setup_output.log 2>&1 &
              EOF
  tags = {
    Name = "jumpbox"
  }
}

resource "aws_instance" "server" {
  ami           = "ami-07564a05443c48891"
  instance_type = "t4g.small"
  key_name = "new"
  network_interface {
    network_interface_id = aws_network_interface.server.id
    device_index         = 0
  }
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = <<-EOF
              #!/bin/bash
              sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
              systemctl restart sshd
              EOF

  tags = {
    Name = "server"
  }
}

resource "aws_instance" "node-0" {
  ami           = "ami-07564a05443c48891"
  instance_type = "t4g.micro"
  key_name = "new"

  network_interface {
    network_interface_id = aws_network_interface.node-0.id
    device_index         = 0
  }

  user_data = <<-EOF
              #!/bin/bash
              sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
              systemctl restart sshd
              EOF

  tags = {
    Name = "node-0"
  }
}

resource "aws_instance" "node-1" {
  ami           = "ami-07564a05443c48891"
  instance_type = "t4g.micro"
  key_name = "new"

  network_interface {
    network_interface_id = aws_network_interface.node-1.id
    device_index         = 0
  }

  user_data = <<-EOF
              #!/bin/bash
              sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
              systemctl restart sshd
              EOF

  tags = {
    Name = "node-1"
  }
}