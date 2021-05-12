#!/usr/bin/bash

instanceip=$(hostname -i)
sudo yum install wget -y
sudo wget --no-check-certificate --no-cookies --header "Cookie: oraclelicense=accept-securebackup-cookie" http://download.oracle.com/otn-pub/java/jdk/8u141-b15/336fa29ff2bb4ef291e347e091f7f4a7/jdk-8u141-linux-x64.rpm
sudo yum install jdk-8u141-linux-x64.rpm -y

sudo wget -c https://archive.apache.org/dist/hadoop/common/hadoop-1.2.1/hadoop-1.2.1-1.x86_64.rpm
sudo rpm -i --force hadoop-1.2.1-1.x86_64.rpm
sudo rm -rf /nn
sudo mkdir /nn

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

if pidof /usr/java/default/bin/java
then sudo kill `pidof /usr/java/default/bin/java`
fi

sudo chmod 777 /etc/rc.d/rc.local
sudo cat <<EOF >> /etc/rc.d/rc.local
sudo hadoop-daemon.sh start tasktracker
EOF


sudo hadoop-daemon.sh start tasktracker