#Script that runs on the jumphost during first bootup to setup the environment

cd /root/kubernetes-the-hard-way

#Fixing hostnames, hosts file
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

#Provision CA and generate certs

openssl genrsa -out ca.key 4096
openssl req -x509 -new -sha512 -noenc -key ca.key -days 3653 -config ca.conf -out ca.crt

certs=(
  "admin" "node-0" "node-1"
  "kube-proxy" "kube-scheduler"
  "kube-controller-manager"
  "kube-api-server"
  "service-accounts"
)

for i in ${certs[*]}; do
  openssl genrsa -out "${i}.key" 4096
  openssl req -new -key "${i}.key" -sha256 -config "ca.conf" -section ${i} -out "${i}.csr"
  openssl x509 -req -days 3653 -in "${i}.csr" -copy_extensions copyall -sha256 -CA "ca.crt" -CAkey "ca.key" -CAcreateserial -out "${i}.crt"
done

#Copy the certs and keys to appropriate servers

for host in node-0 node-1; do
  ssh root@$host mkdir /var/lib/kubelet/

  scp ca.crt root@$host:/var/lib/kubelet/

  scp $host.crt \
    root@$host:/var/lib/kubelet/kubelet.crt

  scp $host.key \
    root@$host:/var/lib/kubelet/kubelet.key
done

scp ca.key ca.crt kube-api-server.key kube-api-server.crt service-accounts.key service-accounts.crt root@server:~/