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

resource "aws_eip" "jumpbox_eip" {
  vpc = true
}

resource "aws_network_interface" "jumpbox" {
  subnet_id   = aws_subnet.my_subnet.id
  private_ips = ["10.134.12.15"]
  security_groups = [aws_security_group.my_group.id]

  tags = {
    Name = "jumpbox primary nw"
  }
}

resource "aws_eip_association" "jumpbox_eip_assoc" {
  network_interface_id = aws_network_interface.jumpbox.id
  allocation_id        = aws_eip.jumpbox_eip.id
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

variable "ssh_public_key" {
  description = "Public key for SSH access"
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC/ApCk3IJ1swt61tL9uD90jWLrDPf/rsSNoUKFUgSe9a0PaW2NZAcbV/mavuj8sFNxI9OjOe8Mlt9l49wIfs89llXU6qbm+cuVdWKFyfd2QyJGxIaPQzL5ZNbpXYaUy2QFQFiqNVyNDDJl466dIJnctxlloL1CkDMqhonPy39DjssXhFcaBbsfOM931zrVfiJ5pwn8Fp0IOOLfGeVuGv7qlZ7bVAGtEXiGcnPjJ8CSdtANUsHqfn74GsEVI3lsqEmUkhjGTDRbYGbsZODioKAdKam9dfu7JFK/VRWsjSNEouAYV8DflgLOAeFitdONGV/raBg0XonsWGyVV7bYTcmD root@Rajeshwers-MacBook-Air.local"
}

variable "ssh_private_key" {
  description = "Private key for SSH access"
  type        = string
  default     = <<-EOF
  -----BEGIN OPENSSH PRIVATE KEY-----
  b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAABFwAAAAdzc2gtcn
  NhAAAAAwEAAQAAAQEAvwKQpNyCdbMLetbS/bg/dI1i6wz3/67EjaFChVIEnvWtD2ltjWQH
  G1f5mr7o/LBTcSPToznvDJbfZePcCH7PPZZV1Oqm5vnLlXVihcn3dkMiRsSGj0My+WTW6V
  2GlMtkBUBYqjVcjQwyZeOunSCZ3LcZZaC9QpAzKoaJz8t/Q47LF4RXGgW7HzjPd9c61X4i
  eacJ/BadCDji3xnlbhr+6pWe21QBrRF4hnJz4yfAknbQDVLB6n5++BrBFSN5bKhJlJIYxk
  w0W2Bm7GTg4qCgHSmpvXX7uyRSv1UVrI0jRKLgGFfA35YCzgHhYrXTjRlf62gYNF6J7Fhs
  lVe22E3JgwAAA+CNil/zjYpf8wAAAAdzc2gtcnNhAAABAQC/ApCk3IJ1swt61tL9uD90jW
  LrDPf/rsSNoUKFUgSe9a0PaW2NZAcbV/mavuj8sFNxI9OjOe8Mlt9l49wIfs89llXU6qbm
  +cuVdWKFyfd2QyJGxIaPQzL5ZNbpXYaUy2QFQFiqNVyNDDJl466dIJnctxlloL1CkDMqho
  nPy39DjssXhFcaBbsfOM931zrVfiJ5pwn8Fp0IOOLfGeVuGv7qlZ7bVAGtEXiGcnPjJ8CS
  dtANUsHqfn74GsEVI3lsqEmUkhjGTDRbYGbsZODioKAdKam9dfu7JFK/VRWsjSNEouAYV8
  DflgLOAeFitdONGV/raBg0XonsWGyVV7bYTcmDAAAAAwEAAQAAAQBkecrwjfYqR7agNWTj
  hgoLG1yPXFEQNDS8c7l0PAKmQ4F3e/PezmFWpt5r4kTYt0ANYdUwJYdzzeFRzZyu81W8hd
  o8l/qXwYqv4gGjcuwzT3k2VKabsbOcsMjEFSh4GM1SXdjGIC/BGktggXYWvVFyYvZ/GSC1
  ZPklQ4Q2xEr7k7YaDGcTTZfSLfu2LlDFo044qq5PUzl3WuN30UT14OLwx3zfTZKPX3rJIP
  DHSbejzbfXuTDUEO6hWjBmLDlsi3qwjD8QRC2ry5qR/10XlHwMNnq7hkTI86xUQwUg6Hbc
  SrcOAOeEHPQJmQEfq2UFEG7J6APT/6ddxfEZX1WzqPdRAAAAgQCNPkhPWtl/70zmpk4ZjA
  RKX3zCrwpnowj/sAa5a/mMi/Cr18xlmlsuYzSHxr9ZRWuRh41mIm2dB3s5BlcQVxH+kkaW
  h5oO3GrKlUK6absALTrB8V99cWkob+FHtkJd6bvkYXbqmRZU6cL6sRaIqd70XeF5KLeBFI
  dbYPkjRUnbLAAAAIEA8FfsW7qMsWJigTdi/CcF7IPHkR7xnvYTEBsGlt6vhSj6/QAJfwqQ
  6gwMyoJ7Uxam8UU9hJH+TB7nrHSjlYZZk7L1i8XZKoufRHT5NasLl095FYMSP21n7XCZwt
  nj3uEgHlUF6m1oeClWFq4i7u3SY632MllgdNFJkfVNGZ4mx30AAACBAMtz71yFQ/53grDl
  Yf/yruVjyMGqzOpjUyysXdPJdjFIN6IHaZD9Sm9+KBoKnmLHcSX0lge05TrlXzUASfObaw
  naXyvaPcuRZbCG0oYrd10CAjZR/xj/1cDHtEnO84cY5gu7+7NymuiuOlVyFBz7Mu+/Rex6
  rr+98UrhRGjHNaT/AAAAJnJhamVzaHdlckBSYWplc2h3ZXJzLU1hY0Jvb2stQWlyLmxvY2
  FsAQIDBA==
  -----END OPENSSH PRIVATE KEY-----
  EOF
}

resource "aws_key_pair" "shared_key" {
  key_name   = "shared_key"
  public_key = var.ssh_public_key
}

resource "aws_instance" "jumpbox" {
  ami           = "ami-07564a05443c48891"
  instance_type = "t4g.nano"
  key_name = "shared_key"
  network_interface {
    network_interface_id = aws_network_interface.jumpbox.id
    device_index         = 0
  }

  root_block_device {
    volume_size = 10
    volume_type = "gp3"
  }
  user_data = <<-EOF
              #!/bin/bash
              sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
              systemctl restart sshd
              echo "${var.ssh_public_key}" >> /home/admin/.ssh/authorized_keys
              echo "${var.ssh_private_key}" >> /home/admin/.ssh/shared_key
              chmod 600 /home/admin/.ssh/authorized_keys
              chmod 600 /home/admin/.ssh/shared_key
              apt-get update
              apt-get -y install wget curl vim openssl git
              cd /root
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
              chmod +x /root/kubernetes-the-hard-way/basic-aws-kubernetes-cluster/setup.sh
              nohup /root/kubernetes-the-hard-way/basic-aws-kubernetes-cluster/setup.sh > /root/setup_output.log 2>&1 &
              EOF
  tags = {
    Name = "jumpbox"
  }
}

resource "aws_instance" "server" {
  ami           = "ami-07564a05443c48891"
  instance_type = "t4g.small"
  key_name = "shared_key"
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
              echo "${var.ssh_public_key}" >> /home/admin/.ssh/authorized_keys
              chmod 600 /root/.ssh/authorized_keys
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
  key_name = "shared_key"

  network_interface {
    network_interface_id = aws_network_interface.node-0.id
    device_index         = 0
  }

  user_data = <<-EOF
              #!/bin/bash
              echo "${var.ssh_public_key}" >> /home/admin/.ssh/authorized_keys
              chmod 600 /root/.ssh/authorized_keys
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
  key_name = "shared_key"

  network_interface {
    network_interface_id = aws_network_interface.node-1.id
    device_index         = 0
  }

  user_data = <<-EOF
              #!/bin/bash
              echo "${var.ssh_public_key}" >> /home/admin/.ssh/authorized_keys
              chmod 600 /root/.ssh/authorized_keys
              sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
              systemctl restart sshd
              EOF

  tags = {
    Name = "node-1"
  }
}