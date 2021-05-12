provider "aws" {
  region     = "ap-south-1"
  profile    = "default"   
} 

#Defining Variables

variable "vpc_id" {
  type = string
  default = "vpc-1e958876"
}

#Defining Hdfs master Configuration

#Method1

locals {
  instance-userdata = <<EOT
#!/usr/bin/bash

instanceip=$(hostname -i)
sudo yum install wget -y
sudo wget --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jdk/8u141-b15/336fa29ff2bb4ef291e347e091f7f4a7/jdk-8u141-linux-x64.rpm
sudo yum install jdk-8u141-linux-x64.rpm -y

sudo wget -c https://archive.apache.org/dist/hadoop/common/hadoop-1.2.1/hadoop-1.2.1-1.x86_64.rpm
sudo rpm -i --force hadoop-1.2.1-1.x86_64.rpm
sudo rm -rf /nn
sudo mkdir /nn

sudo chmod 677 /etc/hadoop/hdfs-site.xml
sudo cat <<EOF > /etc/hadoop/hdfs-site.xml
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>

<configuration>
<property>
<name>dfs.name.dir</name>
<value>/nn</value>
</property>
</configuration>
EOF

sudo chmod 677 /etc/hadoop/core-site.xml
sudo cat <<EOF > /etc/hadoop/core-site.xml
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>

<configuration>
<property>
<name>fs.default.name</name>
<value>hdfs://$instanceip:9001</value>
</property>
</configuration>
EOF


if pidof /usr/java/default/bin/java
then sudo kill `pidof /usr/java/default/bin/java`
fi

sudo echo 'Y' | sudo hadoop namenode -format
sudo hadoop-daemon.sh start namenode

EOT
}

#Method2

data "template_file" "hdfs_master" {
  template = "${file("${path.cwd}/hdfs_master.sh")}"
}


data "template_file" "hdfs_slave" {
  template = "${file("${path.cwd}/hdfs_slave.sh")}"
  vars     = {
    namenode_ip = "${aws_instance.hdfs_master.private_ip}"
  }
  depends_on = [ aws_instance.hdfs_master ]
}

data "template_file" "mapred_jobtracker" {
  template = "${file("${path.cwd}/mapred_jobtracker.sh")}"
}


data "template_file" "mapred_tasktracker" {
  template = "${file("${path.cwd}/mapred_tasktracker.sh")}"
  vars     = {
    jobtracker_ip = "${aws_instance.mapred_jobtracker.private_ip}"
  }
  depends_on = [ aws_instance.mapred_jobtracker ]
}


data "template_file" "hadoop_client" {
  template = "${file("${path.cwd}/hadoop_client.sh")}"
  vars     = {
    namenode_ip = "${aws_instance.hdfs_master.private_ip}"
    jobtracker_ip = "${aws_instance.mapred_jobtracker.private_ip}"
  }
}



#Creating Security Groups for HDFS

resource "aws_security_group" "hdfs_master_sg" {
  name        = "hdfs_master_sg"
  description = "Allow traffic from security group"
  vpc_id      = var.vpc_id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "hdfs_master_sg"
  }
} 

resource "aws_security_group" "hdfs_slave_sg" {
  name        = "hdfs_slave_sg"
  description = "Allow traffic from security group"
  vpc_id      = var.vpc_id

  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    security_groups  = [ "${aws_security_group.hdfs_master_sg.id}" ]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "hdfs_slave_sg"
  }
}

resource "aws_security_group_rule" "hdfs_master_ingress" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = "${aws_security_group.hdfs_master_sg.id}"
  cidr_blocks      = ["0.0.0.0/0"]
  ipv6_cidr_blocks = ["::/0"]
}


#Creating Security Groups for MapReduce

resource "aws_security_group" "mapred_jobtracker_sg" {
  name        = "mapred_jobtracker_sg"
  description = "Allow traffic from security group"
  vpc_id      = var.vpc_id

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "mapred_jobtracker_sg"
  }
}

resource "aws_security_group" "mapred_tasktracker_sg" {
  name        = "mapred_tasktracker_sg"
  description = "Allow traffic from security group"
  vpc_id      = var.vpc_id

  ingress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    security_groups  = [ "${aws_security_group.mapred_jobtracker_sg.id}" ]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "mapred_tasktracker_sg"
  }
}

resource "aws_security_group_rule" "mapred_jobtracker_ingress" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = "${aws_security_group.mapred_jobtracker_sg.id}"
  cidr_blocks      = ["0.0.0.0/0"]
  ipv6_cidr_blocks = ["::/0"]
}


#Launching HDFS Master Instance

resource "aws_instance" "hdfs_master" {
  ami               = "ami-052c08d70def0ac62"
  instance_type     = "t2.micro"
  security_groups   = [ "hdfs_master_sg" ]
  key_name          = "aws_cloud_key"
  user_data = "${data.template_file.hdfs_master.template}"
  tags = {
    Name = "hdfs-master"
  }

}

# Launching HDFS Slaves

resource "aws_instance" "hdfs_slave1" {
  ami              = "ami-052c08d70def0ac62"
  instance_type    = "t2.micro"
  security_groups  = [ "hdfs_slave_sg" ]
  key_name         = "aws_cloud_key"
  associate_public_ip_address = false
  user_data = "${data.template_file.hdfs_slave.rendered}"
  tags = {
    Name = "hdfs-slave1"
  }

  depends_on = [ aws_instance.hdfs_master ]
}


resource "aws_instance" "hdfs_slave2" {
  ami              = "ami-052c08d70def0ac62"
  instance_type    = "t2.micro"
  security_groups  = [ "hdfs_slave_sg" ]
  key_name         = "aws_cloud_key"
  associate_public_ip_address = false
  user_data = "${data.template_file.hdfs_slave.rendered}"
  tags = {
    Name = "hdfs-slave2"
  }

  depends_on = [ aws_instance.hdfs_master ]
}

resource "aws_instance" "hdfs_slave3" {
  ami              = "ami-052c08d70def0ac62"
  instance_type    = "t2.micro"
  security_groups  = [ "hdfs_slave_sg" ]
  key_name         = "aws_cloud_key"
  associate_public_ip_address = false
  user_data = "${data.template_file.hdfs_slave.rendered}"
  tags = {
    Name = "hdfs-slave3"
  }

  depends_on = [ aws_instance.hdfs_master ]
}

#Launching MapReduce master

resource "aws_instance" "mapred_jobtracker" {
  ami               = "ami-052c08d70def0ac62"
  instance_type     = "t2.micro"
  security_groups   = [ "mapred_jobtracker_sg" ]
  key_name          = "aws_cloud_key"
  user_data = "${data.template_file.mapred_jobtracker.template}"
  tags = {
    Name = "mapred_jobtracker"
  }

}


#Launching MapReduce slaves

resource "aws_instance" "mapred_tasktracker1" {
  ami              = "ami-052c08d70def0ac62"
  instance_type    = "t2.micro"
  security_groups  = [ "mapred_tasktracker_sg" ]
  key_name         = "aws_cloud_key"
  associate_public_ip_address = false
  user_data = "${data.template_file.mapred_tasktracker.rendered}"
  tags = {
    Name = "mapred_tasktracker1"
  }

  depends_on = [ aws_instance.mapred_jobtracker ]
}


resource "aws_instance" "mapred_tasktracker2" {
  ami              = "ami-052c08d70def0ac62"
  instance_type    = "t2.micro"
  security_groups  = [ "mapred_tasktracker_sg" ]
  key_name         = "aws_cloud_key"
  associate_public_ip_address = false
  user_data = "${data.template_file.mapred_tasktracker.rendered}"
  tags = {
    Name = "mapred_tasktracker2"
  }

  depends_on = [ aws_instance.mapred_jobtracker ]
}


resource "aws_instance" "mapred_tasktracker3" {
  ami              = "ami-052c08d70def0ac62"
  instance_type    = "t2.micro"
  security_groups  = [ "mapred_jobtracker_sg" ]
  key_name         = "aws_cloud_key"
  associate_public_ip_address = false
  user_data = "${data.template_file.mapred_tasktracker.rendered}"
  tags = {
    Name = "mapred_tasktracker3"
  }

  depends_on = [ aws_instance.mapred_jobtracker ]
}


resource "aws_instance" "hadoop_client" {
  ami              = "ami-052c08d70def0ac62"
  instance_type    = "t2.micro"
  security_groups  = [ "mysecurity-group" ]
  key_name         = "aws_cloud_key"
  user_data = "${data.template_file.hadoop_client.rendered}"
  tags = {
    Name = "hadoop_client"
  }
}


output "hdfs_master_public_IP" {
  value = aws_instance.hdfs_master.public_ip
}

output "hdfs_master_private_IP" {
  value = aws_instance.hdfs_master.private_ip
}


output "mapred_jobtracker_public_IP" {
  value = aws_instance.mapred_jobtracker.public_ip
}

output "mapred_jobtracker_private_IP" {
  value = aws_instance.mapred_jobtracker.private_ip
}


output "Hadooop_client_public_IP" {
  value = aws_instance.hadoop_client.public_ip
}














/*

Note: This is very important Render 
output "Renderedinfo" {
  value = data.template_file.hdfs_slave.rendered
}

*/