provider "aws" {
  region = "us-east-1"
}
//create a vpc
resource "aws_vpc" "sub-vpc" {
  cidr_block = "10.0.0.0/16"
tags = {
    Name = "production"
  }
}

//create a gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.sub-vpc.id

}

//create a custom route table
resource "aws_route_table" "sub-route-table" {
  vpc_id = aws_vpc.sub-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id =  aws_internet_gateway.gw.id
  }

  tags = {
    Name = "prod"
  }
}
//create a subnet

resource "aws_subnet" "subnet-1" {
  vpc_id     =aws_vpc.sub-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "prod-subnet"
  }
}

//Associate subnet with route table

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.sub-route-table.id
}

//create security group

resource "aws_security_group" "allow_web" {
  name        = "allow_web traffic"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.sub-vpc.id

  
ingress {
    description     = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    

  }
  ingress {
    description     = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    
  }

  ingress {
    description     = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1" // -1 means any protocol
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}
//create a network interface with an ip inthe subnet created in the step 4 
resource "aws_network_interface" "web-serve-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}

//Assign an elstic Ip to network interface 

resource "aws_eip" "once" {
  domain                    = "vpc"  // vpc =true
  network_interface         = aws_network_interface.web-serve-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [ aws_internet_gateway.gw ]

}

//created ubuntu server

resource "aws_instance" "web-serv-instan" {
  ami ="ami-04b70fa74e45c3917"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name ="main"

  network_interface {
  device_index = 0
  network_interface_id =aws_network_interface.web-serve-nic.id
  }

user_data = <<-EOF
             #!/bin/bash
             sudo apt update -y
             sudo apt install apache2 -y
             sudo systemctl start apache
             sudo bash -c 'echo Have a beautiful day > /var/www/html/index.html'
            EOF

   tags ={
    name = "Web-server"
   }         
}


