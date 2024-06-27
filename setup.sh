#Script that runs on the jumphost during first bootup to setup the environment

ssh-keygen -q -t rsa -N "" -f /root/.ssh/id_rsa

while read IP FQDN HOST SUBNET; do
  ssh-copy-id root@${IP}
done < machines.txt

while read IP FQDN HOST SUBNET; do
    CMD="sed -i 's/^127.0.1.1.*/127.0.1.1\t${FQDN} ${HOST}/' /etc/hosts"
    ssh -n root@${IP} "$CMD"
    ssh -n root@${IP} hostnamectl hostname ${HOST}
done < machines.txt

while read IP FQDN HOST SUBNET; do
    ENTRY="${IP} ${FQDN} ${HOST}"
    echo $ENTRY >> /etc/hosts
done < machines.txt

while read IP FQDN HOST SUBNET; do
  scp /etc/hosts root@${HOST}:~/
  ssh -n root@${HOST} "cat hosts >> /etc/hosts"
done < machines.txt