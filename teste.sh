#!/usr/bin/env bash

source func.sh

IP_ATUAL=$(hostname -I)
HOSTNAME=$(hostname)
NETMASK=$(ifconfig |grep netmask | grep -v 127.0.0.1 | awk '{print $4}')
NONE_REDE=$(ip -o -4 route show to default | awk '{print $5}' | uniq)

which ifconfig || yum install net-tools -y
clear
echo "Esse script usa o IP e o nome da maquina para criar a integração entre o DHCP e o DNS"
echo "Caso essas informações não estiverem definidas, Rodar esse script depois da configuração"
echo "realizada"

echo "IP...................= [ $IP_ATUAL ]"
echo "Máscara de rede......= [ $NETMASK ] "
echo "Nome da maquina......= [ $HOSTNAME ]"

cat /etc/sysconfig/network-scripts/ifcfg-$NONE_REDE |grep dhcp > /dev/null
if [[ $? -eq 0 ]]; then
  echo "Configuração de rede está em DHCP, favor realizar configuração estática"
  exit 4
fi

echo "Deseja continuar S/N: "
read ENTRADA

if [[ $ENTRADA = "S" || $ENTRADA = "s" ]]; then
  clear
  echo "Realizando configuração"
  _CONFIGURAR
  _DEPENDENCIA
  _VIM
  _PRINCIPAL
  _RESOLV
else
  echo "Script finalizado"
fi
