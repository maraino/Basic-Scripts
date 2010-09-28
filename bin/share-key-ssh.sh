#!/bin/sh

function usage() {
 echo "Use: $0 [-p port] [-l user] [-h] <hostname>"
 echo "To generate the keys: $0 -g"
}

port=22
user=root
server=""
i=0

for arg in $@
do
  if [ $arg == "-g" ]
  then
	  echo "Running:"
	  echo "ssh-keygen -t dsa"
	  ssh-keygen -t dsa
	  exit 0
  fi
done

while getopts ":p:l:h:*" options; do
	case $options in
		p ) port=$OPTARG
		    ((i+=2));;
		l ) user=$OPTARG
		    ((i+=2));;
		h ) server=$OPTARG
		    ((i+=2));;
		\? ) usage
		exit 1;;
		* ) server=$options;;
  esac
done

if [[ $# -gt $i ]]
then
	if [ -z $server ]
	then
		server=${!#}
	fi
fi

if [ -z $server ]
then
	usage
	exit 1
fi

echo "Running:"
echo "ssh -p $port $user@$server 'cat >> ~/.ssh/authorized_keys' < ~/.ssh/id_rsa.pub"
ssh -p $port $user@$server 'cat >> .ssh/authorized_keys' < ~/.ssh/id_rsa.pub
