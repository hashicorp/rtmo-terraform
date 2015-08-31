//Provider
provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "us-east-1"
}

// SSH Keys
module "ssh_keys" {
  source = "./ssh_keys"

  name = "${var.key_name}"
}

//Networking
resource "aws_vpc" "vpc" {
  cidr_block           = "${var.vpc_cidr}"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags { Name = "${var.name}" }
  lifecycle { create_before_destroy = true }
}

resource "aws_internet_gateway" "public" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags { Name = "${var.name}" }
  lifecycle { create_before_destroy = true }
}

resource "aws_subnet" "public" {
  vpc_id            = "${aws_vpc.vpc.id}"
  cidr_block        = "${var.subnet_cidr}"
  availability_zone = "us-east-1b"

  tags { Name = "${var.name}" }
  lifecycle { create_before_destroy = true }

  map_public_ip_on_launch = true
}

resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.vpc.id}"

  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = "${aws_internet_gateway.public.id}"
  }
  tags { Name = "${var.name}" }
  lifecycle { create_before_destroy = true }
}

resource "aws_route_table_association" "public" {
  subnet_id      = "${aws_subnet.public.id}"
  route_table_id = "${aws_route_table.public.id}"
  
  lifecycle { create_before_destroy = true }
}

//MongoDB Security Group
resource "aws_security_group" "mongodb" {
  name        = "mongodb"
  vpc_id      = "${aws_vpc.vpc.id}"
  description = "Allow all inbound traffic from VPC and SSH from world"

  tags { Name = "${var.name}-mongodb" }
  lifecycle { create_before_destroy = true }

  ingress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

//MongoDB Instance
resource "aws_instance" "mongodb" {
  ami           = "ami-cf5beba4"
  instance_type = "t2.micro"
  key_name      = "${module.ssh_keys.key_name}"
  subnet_id     = "${aws_subnet.public.id}"

  vpc_security_group_ids = ["${aws_security_group.mongodb.id}"]

  tags { Name = "${var.name}-mongodb" }
  lifecycle { create_before_destroy = true }

  provisioner "remote-exec" {
    connection {
      user     = "ubuntu"
      key_file = "${module.ssh_keys.private_key_path}"
    }

    inline = [
      "sudo apt-key adv --keyserver keyserver.ubuntu.com --recv 7F0CEB10",
      "sudo echo \"deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen\" | sudo tee -a /etc/apt/sources.list.d/10gen.list",
      "sudo wget -P /tmp https://apt.puppetlabs.com/puppetlabs-release-precise.deb",
      "sudo dpkg -i /tmp/puppetlabs-release-precise.deb",
      "sudo apt-get -y update",
      "sudo apt-get -y install puppet vim git",
      "sudo puppet module install jay-letschat",
      "sudo puppet apply -e \"class { 'letschat::db': user => 'lcadmin', pass => 'somepass', database_name => 'letschat', }\""
    ]
  }
}

//Node.js Security Group
resource "aws_security_group" "nodejs" {
  name        = "nodejs"
  vpc_id      = "${aws_vpc.vpc.id}"
  description = "Allow all inbound traffic from VPC and SSH from world"

  tags { Name = "${var.name}-nodejs" }
  lifecycle { create_before_destroy = true }

  ingress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    protocol    = "tcp"
    from_port   = 5000
    to_port     = 5000
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

//Node.js Instance
resource "aws_instance" "nodejs" {
  ami             = "ami-cf5beba4"
  instance_type   = "t2.micro"
  key_name        = "${module.ssh_keys.key_name}"
  subnet_id       = "${aws_subnet.public.id}"

  vpc_security_group_ids = ["${aws_security_group.nodejs.id}"]

  tags { Name = "${var.name}-nodejs" }
  lifecycle { create_before_destroy = true }
  depends_on = ["aws_instance.mongodb"]

  provisioner "remote-exec" {
    connection {
      user     = "ubuntu"
      key_file = "${module.ssh_keys.private_key_path}"
    }

    inline = [
      "sudo apt-key adv --keyserver keyserver.ubuntu.com --recv 7F0CEB10",
      "sudo echo \"deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen\" | sudo tee -a /etc/apt/sources.list.d/10gen.list",
      "sudo wget -P /tmp https://apt.puppetlabs.com/puppetlabs-release-precise.deb",
      "sudo dpkg -i /tmp/puppetlabs-release-precise.deb",
      "sudo apt-get -y update",
      "sudo apt-get -y install puppet vim git",
      "sudo puppet module install jay-letschat",
      "sudo puppet apply -e \"class { 'letschat::app': dbuser => 'lcadmin', dbpass => 'somepass', dbname => 'letschat', dbhost => '${aws_instance.mongodb.private_dns}', }\""
    ]
  }
}

output "letschat_address" {
  value = "http://${aws_instance.nodejs.public_ip}:5000"
}
