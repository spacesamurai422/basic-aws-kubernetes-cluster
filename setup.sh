#!/bin/bash

#Script that runs on the jumphost during first bootup to setup the environment

cd /root/kubernetes-the-hard-way

#Fixing hostnames, hosts file
while read IP FQDN HOST SUBNET; do
    #CMD="sed -i 's/^127.0.1.1.*/127.0.1.1\t${FQDN} ${HOST}/' /etc/hosts" ##still not working
    ssh -o StrictHostKeyChecking=no -n admin@"${IP}" "sudo sed -i 's/^127.0.1.1.*/127.0.1.1\t${FQDN} ${HOST}/' /etc/hosts"
    ssh -o StrictHostKeyChecking=no -n admin@"${IP}" sudo hostnamectl hostname ${HOST}
done < machines.txt

while read IP FQDN HOST SUBNET; do
    ENTRY="${IP} ${FQDN} ${HOST}"
    echo $ENTRY | sudo tee -a /etc/hosts
done < machines.txt

while read IP FQDN HOST SUBNET; do
  scp -o StrictHostKeyChecking=no /etc/hosts admin@${HOST}:~/
  ssh -o StrictHostKeyChecking=no -n admin@${HOST} "cat hosts | sudo tee -a /etc/hosts"
done < machines.txt

#Provision CA and generate certs

openssl genrsa -out ca.key 4096
openssl req -x509 -new -sha512 -noenc -key ca.key -days 3653 -config ca.conf -out ca.crt

certs=("admin" "node-0" "node-1" "kube-proxy" "kube-scheduler" "kube-controller-manager" "kube-api-server" "service-accounts")

for i in ${certs[*]}; do
  openssl genrsa -out "${i}.key" 4096
  openssl req -new -key "${i}.key" -sha256 -config "ca.conf" -section ${i} -out "${i}.csr"
  openssl x509 -req -days 3653 -in "${i}.csr" -copy_extensions copyall -sha256 -CA "ca.crt" -CAkey "ca.key" -CAcreateserial -out "${i}.crt"
done

#Copy the certs and keys to appropriate servers

for host in node-0 node-1; do
  ssh -o StrictHostKeyChecking=no admin@$host sudo mkdir /var/lib/kubelet/

  scp -o StrictHostKeyChecking=no ca.crt admin@$host:/tmp/
  ssh -o StrictHostKeyChecking=no admin@$host sudo mv /tmp/ca.crt /var/lib/kubelet/

  scp -o StrictHostKeyChecking=no $host.crt admin@$host:/tmp/kubelet.crt
  ssh -o StrictHostKeyChecking=no admin@$host sudo mv /tmp/kubelet.crt /var/lib/kubelet/


  scp $host.key admin@$host:/tmp/kubelet.key
  ssh admin@$host sudo mv /tmp/kubelet.key /var/lib/kubelet/

done

scp ca.key ca.crt kube-api-server.key kube-api-server.crt service-accounts.key service-accounts.crt admin@server:/tmp

#Generate kubeconfig files

#kubeconfig for kubelets
for host in node-0 node-1; do
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.crt \
    --embed-certs=true \
    --server=https://server.kubernetes.local:6443 \
    --kubeconfig=${host}.kubeconfig

  kubectl config set-credentials system:node:${host} \
    --client-certificate=${host}.crt \
    --client-key=${host}.key \
    --embed-certs=true \
    --kubeconfig=${host}.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:node:${host} \
    --kubeconfig=${host}.kubeconfig

  kubectl config use-context default \
    --kubeconfig=${host}.kubeconfig
done

#kubeconfig for kube-proxy service
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.crt \
  --embed-certs=true \
  --server=https://server.kubernetes.local:6443 \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-credentials system:kube-proxy \
  --client-certificate=kube-proxy.crt \
  --client-key=kube-proxy.key \
  --embed-certs=true \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig

kubectl config use-context default \
  --kubeconfig=kube-proxy.kubeconfig

#kubeconfig for kube-controller-manager service
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.crt \
  --embed-certs=true \
  --server=https://server.kubernetes.local:6443 \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-credentials system:kube-controller-manager \
  --client-certificate=kube-controller-manager.crt \
  --client-key=kube-controller-manager.key \
  --embed-certs=true \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-controller-manager \
  --kubeconfig=kube-controller-manager.kubeconfig

kubectl config use-context default \
  --kubeconfig=kube-controller-manager.kubeconfig

#kubeconfig for kube-scheduler service
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.crt \
  --embed-certs=true \
  --server=https://server.kubernetes.local:6443 \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-credentials system:kube-scheduler \
  --client-certificate=kube-scheduler.crt \
  --client-key=kube-scheduler.key \
  --embed-certs=true \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=system:kube-scheduler \
  --kubeconfig=kube-scheduler.kubeconfig

kubectl config use-context default \
  --kubeconfig=kube-scheduler.kubeconfig

#kubeconfig for admin user
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=ca.crt \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=admin.kubeconfig

kubectl config set-credentials admin \
  --client-certificate=admin.crt \
  --client-key=admin.key \
  --embed-certs=true \
  --kubeconfig=admin.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=admin \
  --kubeconfig=admin.kubeconfig

kubectl config use-context default \
  --kubeconfig=admin.kubeconfig

#Copy the kubelet and kube-proxy configs to their respective nodes
for host in node-0 node-1; do
  ssh admin@$host "sudo mkdir /var/lib/{kube-proxy,kubelet}"

  scp -o StrictHostKeyChecking=no kube-proxy.kubeconfig admin@$host:/tmp/kubeconfig
  ssh -o StrictHostKeyChecking=no admin@$host sudo mv /tmp/kubeconfig /var/lib/kube-proxy/

  scp -o StrictHostKeyChecking=no ${host}.kubeconfig admin@$host:/tmp/kubeconfig
  ssh -o StrictHostKeyChecking=no admin@$host sudo mv /tmp/kubeconfig /var/lib/kubelet/

done

scp admin.kubeconfig kube-controller-manager.kubeconfig kube-scheduler.kubeconfig admin@server:/tmp

#Generate encryption config
export ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
envsubst < configs/encryption-config.yaml > encryption-config.yaml
scp encryption-config.yaml admin@server:/tmp
