#!/bin/bash

_CONFIGURAR()
{
  sleep 1
  clear
  FILE="/tmp/inicial.txt"
  if [ ! -e "$FILE" ] ; then
  #Desabilitar o firewalld
    systemctl stop firewalld
    systemctl disable firewalld
  #Desabilitar SELINUX
    setenforce 0
    sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config
  #Instalar repositorio EPEL
    yum install epel-release.noarch -y
    yum install epel-release yum-utils -y

  #Atualizar sistema
    yum update -y && yum upgrade -y

  #Instalar dependencias
    yum install -y bind bind-utils dhcp vim net-tools
  #Habilita na inicialização    
    systemctl enable named
    systemctl enable dhcpd
    rndc-confgen -a
    echo "Configuracao realizada" > $FILE
  else
    echo "Configuracao realizada, para repetir a instalacao remover esse arquivo $FILE"
  fi
}

_DEPENDENCIA()
{
  clear
  #Verifica se comando which existe, senão realiza a instalação
  which ntpdate || yum install ntpdate -y && ntpdate a.ntp.br
  echo "Data e hora atualizados"
}

_VIM()
{
  FILE="/tmp/vim.txt"
  LOCAL_VIM=$(whereis vimrc |cut -d " " -f2) 
  echo "$FILE"

  if [ ! -e "$FILE" ] ; then
      echo "Criando arquivo de configuracao"
      sed -i 's/set\ nocompatible/set\ bg\=\dark\nset\ nocompatible/'     $LOCAL_VIM
      sed -i 's/set\ nocompatible/set\ tabstop\=4\nset\ nocompatible/'    $LOCAL_VIM
      sed -i 's/set\ nocompatible/set\ shiftwidth\=4\nset\ nocompatible/' $LOCAL_VIM
      sed -i 's/set\ nocompatible/set\ expandtab\nset\ nocompatible/'     $LOCAL_VIM
      sed -i 's/set\ nocompatible/syntax\ on\nset\ nocompatible/'         $LOCAL_VIM
      sed -i 's/set\ nocompatible/set\ number\nset\ nocompatible/'        $LOCAL_VIM
      echo "Configuracao realizada" > $FILE
  else
    echo "Configuracao realizada, para repetir a instalacao remover esse arquivo $FILE"
  fi
    head -n 20 /etc/vimrc
    echo $LOCAL_VIM
}

_PRINCIPAL()
{

  clear
  echo "Digite o nome da zona dns a ser criada: Ex lab.local, empresa.intra"
  read ZONA
  echo "Digite o nome da zona reversa a ser criada: Ex 1.168.192, 0.0.10, 0.16.172"
  read REVERSO
  echo "Digite o endereço de rede: EX 10.0.0.0, 192.168.0.0, 172.16.0.0"
  read E_REDE
  echo "Digite o endereço INICIAL do DHCP: Ex 192.168.0.100"
  read END_INICIAL
  echo "Digite o endereço FINAL do DHCP: Ex 192.168.0.150"
  read END_FINAL
  echo "Qual nome desse máquina"
  read HOSN
  hostnamectl set-hostname $HOSN  

  echo "$ZONA"
  echo "$REVERSO"
  echo "$E_REDE"
  echo "$HOSN"
  NAMED="/etc/named.conf"
  DHCP="/etc/dhcp/dhcpd.conf"
  ZONE="/var/named/dynamic/$ZONA"
  REVE="/var/named/dynamic/$REVERSO.in-addr.arpa"
  IP=$(hostname -I)
  NETMASK=$(ifconfig |grep netmask | grep -v 127.0.0.1 | awk '{print $4}')
  NOME_REDE=$(ip -o -4 route show to default | awk '{print $5}' | uniq)
  GATEWAY=$(ip -o -4 route show to default |awk '{print $3}' |tail -n 1)
  H_NAME=$(hostname -f)  

  FILE="/tmp/principal.txt"
  if [ ! -e "$FILE" ] ; then
  #echo "include \"/etc/rndc.key\";" >> /etc/named.conf
    cp /var/named/named.empty $ZONE
    cp /var/named/named.empty $REVE
    chown named.named /var/named/dynamic/*
############################# NAMED ##############################################3
cat > $NAMED << EOF
options {
	listen-on port 53 { any; };
	listen-on-v6 port 53 { any; };
	directory 	"/var/named";
	dump-file 	"/var/named/data/cache_dump.db";
	statistics-file "/var/named/data/named_stats.txt";
	memstatistics-file "/var/named/data/named_mem_stats.txt";
	recursing-file  "/var/named/data/named.recursing";
	secroots-file   "/var/named/data/named.secroots";
	allow-query     { any; };
	recursion yes;

	dnssec-enable yes;
	dnssec-validation yes;

	/* Path to ISC DLV key */
	bindkeys-file "/etc/named.iscdlv.key";

	managed-keys-directory "/var/named/dynamic";

	pid-file "/run/named/named.pid";
	session-keyfile "/run/named/session.key";
	forwarders {
		$IP;
		8.8.8.8;
	};
};

logging {
        channel default_debug {
                file "data/named.run";
                severity dynamic;
        };
};

zone "." IN {
	type hint;
	file "named.ca";
};

include "/etc/named.rfc1912.zones";
include "/etc/named.root.key";
include "/etc/rndc.key";

zone "$ZONA" {
	type master;
	file "dynamic/$ZONA";
	allow-update { key rndc-key; };
};

zone "$REVERSO.in-addr.arpa" {
	type master;
	file "dynamic/$REVERSO.in-addr.arpa";
	allow-update { key rndc-key; };
};
EOF
######################################## DHCP #####################################
cat > $DHCP << EOF
ddns-update-style interim;
ddns-updates on;
allow booting;
allow bootp;
authoritative;

key rndc-key {
	algorithm hmac-md5;
	secret mBdnnBjbosbDTO/Z2sAu0A==;
}

ignore client-updates;
set vendorclass = option vendor-class-identifier;

subnet $E_REDE netmask $NETMASK {
	interface $NOME_REDE;
	option routers			$GATEWAY;
	option domain-name-servers	$GATEWAY;
	option domain-name		"$ZONA";
	option subnet-mask		$NETMASK;
	range				$END_INICIAL $END_FINAL;
	filename			"/pxelinux.0";
	default-lease-time		21600;
	max-lease-time			43200;
	next-server			$GATEWAY;
}

zone $ZONA. {
	primary localhost;
	key rndc-key;
}

zone $REVERSO.in-addr.arpa. {
	primary localhost;
	key rndc-key;
}
EOF
SECRET=$(cat /etc/rndc.key |grep secret |cut -d " " -f 2 |sed s'/"//g')
sed -i "s/secret.*/secret $SECRET/g" /etc/dhcp/dhcpd.conf

############################### ZONAS #########################################
#@   IN  SOA @   $ZONA $H_NAME.$ZONA. (
NOVO_HOSTNAME=$(hostnamectl |grep hostname | awk '{print $3}')
TTL=$(echo "\$TTL")

cat > $ZONE << EOF
$TTL 3H ; 3 hours
@   IN  SOA @   $NOVO_HOSTNAME.$ZONA. (
				1          ; serial
				86400      ; refresh (1 day)
				3600       ; retry (1 hour)
				604800     ; expire (1 week)
				10800      ; minimum (3 hours)
				)
            IN  NS  $NOVO_HOSTNAME.$ZONA.
$H_NAME     IN  A   $IP
EOF

cat > $REVE << EOF
$TTL 3H
@   IN  SOA @   $NOVO_HOSTNAME.$ZONA. (
				1          ; serial
				86400      ; refresh (1 day)
				3600       ; retry (1 hour)
				604800     ; expire (1 week)
				10800      ; minimum (3 hours)
				)
            NS  $NOVO_HOSTNAME.$ZONA.
1           PTR $NOVO_HOSTNAME.$ZONA.
EOF
    chown named.named /var/named/dynamic/*
    sleep 1
    chown root:named /etc/rndc.key
    chmod 640 /etc/rndc.key
    systemctl restart named
    systemctl restart dhcpd
    echo "Configuracao realizada" > $FILE
  else
    echo "Configuracao realizada, para repetir a instalacao remover esse arquivo $FILE"
  fi
}
#################################### RESOLV #############################
_RESOLV()
{
  chattr -i /etc/resolv.conf
  FILE="/tmp/resolv.txt"
  CAM="/etc/resolv.conf"
  if [ ! -e "$FILE" ] ; then
  cat > $CAM << EOF
search $ZONA
domain $ZONA
nameserver $IP
nameserver 8.8.8.8
EOF
  chattr +i /etc/resolv.conf
  else
    echo "Configuracao realizada, para repetir a instalacao remover esse arquivo $FILE"
  fi
}
