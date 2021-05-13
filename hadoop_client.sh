#!/usr/bin/bash

instanceip=$(hostname -i)
sudo yum install wget -y
sudo wget --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jdk/8u141-b15/336fa29ff2bb4ef291e347e091f7f4a7/jdk-8u141-linux-x64.rpm
sudo yum install jdk-8u141-linux-x64.rpm -y

sudo wget -c https://archive.apache.org/dist/hadoop/common/hadoop-1.2.1/hadoop-1.2.1-1.x86_64.rpm
sudo rpm -i --force hadoop-1.2.1-1.x86_64.rpm


sudo chmod 677 /etc/hadoop/core-site.xml
sudo cat <<EOF > /etc/hadoop/core-site.xml
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>

<configuration>
<property>
<name>fs.default.name</name>
<value>hdfs://${namenode_ip}:9001</value>
</property>
</configuration>
EOF


sudo chmod 677 /etc/hadoop/mapred-site.xml
sudo cat <<EOF > /etc/hadoop/mapred-site.xml
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>

<configuration>
<property>
<name>mapred.job.tracker</name>
<value>${jobtracker_ip}:9002</value>
</property>
</configuration>
EOF

sudo wget -c https://archive.apache.org/dist/hive/hive-0.13.1/apache-hive-0.13.1-bin.tar.gz
sudo tar -xvf apache-hive-0.13.1-bin.tar.gz -C /opt/

cat <<EOF >> .bashrc
export PATH=/opt/apache-hive-0.13.1-bin/bin/:\$PATH
export HIVE_HOME=/opt/apache-hive-0.13.1-bin/
EOF