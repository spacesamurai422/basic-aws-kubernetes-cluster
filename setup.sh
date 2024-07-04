#!/bin/bash

#Script that runs on the jumphost during first bootup to setup the environment

cd /root/kubernetes-the-hard-way

#Fixing hostnames, hosts file
while read IP FQDN HOST SUBNET; do
    #CMD="sed -i 's/^127.0.1.1.*/127.0.1.1\t${FQDN} ${HOST}/' /etc/hosts" ##still not working
    sudo sed -i "/^127\.0\.0\.1/c\127.0.0.1 ${FQDN} ${HOST}" /etc/hosts
    ssh -o StrictHostKeyChecking=no -n admin@${IP} sudo sed -i "/^127\.0\.0\.1/c\127.0.0.1 ${FQDN} ${HOST}" /etc/hosts
    ssh -o StrictHostKeyChecking=no -n admin@${IP} sudo hostnamectl hostname ${HOST}
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
  ssh -o StrictHostKeyChecking=no admin@$host sudo mkdir /var/lib/kubelet

  scp -o StrictHostKeyChecking=no ca.crt admin@$host:/tmp/
  ssh -o StrictHostKeyChecking=no admin@$host sudo mv /tmp/ca.crt /var/lib/kubelet/

  scp -o StrictHostKeyChecking=no $host.crt admin@$host:/tmp/kubelet.crt
  ssh -o StrictHostKeyChecking=no admin@$host sudo mv /tmp/kubelet.crt /var/lib/kubelet/

  scp -o StrictHostKeyChecking=no $host.key admin@$host:/tmp/kubelet.key
  ssh -o StrictHostKeyChecking=no admin@$host sudo mv /tmp/kubelet.key /var/lib/kubelet/

done

scp -o StrictHostKeyChecking=no ca.key ca.crt kube-api-server.key kube-api-server.crt service-accounts.key service-accounts.crt admin@server:/tmp

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
  ssh -o StrictHostKeyChecking=no admin@$host "sudo mkdir /var/lib/{kube-proxy,kubelet}"

  scp -o StrictHostKeyChecking=no kube-proxy.kubeconfig admin@$host:/tmp/kubeconfig
  ssh -o StrictHostKeyChecking=no admin@$host sudo mv /tmp/kubeconfig /var/lib/kube-proxy/

  scp -o StrictHostKeyChecking=no ${host}.kubeconfig admin@$host:/tmp/kubeconfig
  ssh -o StrictHostKeyChecking=no admin@$host sudo mv /tmp/kubeconfig /var/lib/kubelet/

done

scp -o StrictHostKeyChecking=no admin.kubeconfig kube-controller-manager.kubeconfig kube-scheduler.kubeconfig admin@server:/tmp

#Generate encryption config
export ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)
envsubst < basic-aws-kubernetes-cluster/encryption-config.yaml > encryption-config.yaml
scp -o StrictHostKeyChecking=no encryption-config.yaml admin@server:/tmp

#Bootstrap etcd on server
scp -o StrictHostKeyChecking=no downloads/etcd-v3.4.27-linux-arm64.tar.gz units/etcd.service admin@server:/tmp
ssh -o StrictHostKeyChecking=no admin@server sudo tar -xvf /tmp/etcd-v3.4.27-linux-arm64.tar.gz -C /tmp
ssh -o StrictHostKeyChecking=no admin@server sudo mv /tmp/etcd-v3.4.27-linux-arm64/etcd* /usr/local/bin/
ssh -o StrictHostKeyChecking=no admin@server sudo mkdir -p /etc/etcd /var/lib/etcd
ssh -o StrictHostKeyChecking=no admin@server sudo chmod 700 /var/lib/etcd
ssh -o StrictHostKeyChecking=no admin@server sudo cp /tmp/ca.crt /tmp/kube-api-server.key /tmp/kube-api-server.crt /etc/etcd/
ssh -o StrictHostKeyChecking=no admin@server sudo mv /tmp/etcd.service /etc/systemd/system/
ssh -o StrictHostKeyChecking=no admin@server sudo systemctl daemon-reload
ssh -o StrictHostKeyChecking=no admin@server sudo systemctl enable etcd
ssh -o StrictHostKeyChecking=no admin@server sudo systemctl start etcd
etcdctl member list

#Bootstrap the control plane server - api server, scheduler, controller manager
scp \
  downloads/kube-apiserver \
  downloads/kube-controller-manager \
  downloads/kube-scheduler \
  downloads/kubectl \
  units/kube-apiserver.service \
  units/kube-controller-manager.service \
  units/kube-scheduler.service \
  configs/kube-scheduler.yaml \
  configs/kube-apiserver-to-kubelet.yaml \
  admin@server:/tmp

ssh -o StrictHostKeyChecking=no admin@server sudo mkdir -p /etc/kubernetes/config
ssh -o StrictHostKeyChecking=no admin@server sudo chmod +x /tmp/kube-apiserver /tmp/kube-controller-manager /tmp/kube-scheduler /tmp/kubectl
ssh -o StrictHostKeyChecking=no admin@server sudo mv /tmp/kube-apiserver /tmp/kube-controller-manager /tmp/kube-scheduler /tmp/kubectl /usr/local/bin/


#Configure kubernetes api server, controller manager and scheduler
ssh -o StrictHostKeyChecking=no admin@server sudo mkdir -p /var/lib/kubernetes/
ssh -o StrictHostKeyChecking=no admin@server sudo mv /tmp/ca.crt /tmp/ca.key /tmp/kube-api-server.key /tmp/kube-api-server.crt /tmp/service-accounts.key /tmp/service-accounts.crt /tmp/encryption-config.yaml /var/lib/kubernetes/
ssh -o StrictHostKeyChecking=no admin@server sudo mv /tmp/kube-apiserver.service /etc/systemd/system/kube-apiserver.service

ssh -o StrictHostKeyChecking=no admin@server sudo mv /tmp/kube-controller-manager.kubeconfig /var/lib/kubernetes/
ssh -o StrictHostKeyChecking=no admin@server sudo mv /tmp/kube-controller-manager.service /etc/systemd/system/

ssh -o StrictHostKeyChecking=no admin@server sudo mv /tmp/kube-scheduler.kubeconfig /var/lib/kubernetes/
ssh -o StrictHostKeyChecking=no admin@server sudo mv /tmp/kube-scheduler.service /etc/systemd/system/
ssh -o StrictHostKeyChecking=no admin@server sudo mv /tmp/kube-scheduler.yaml /etc/kubernetes/config/

#Start control plane services
ssh -o StrictHostKeyChecking=no admin@server sudo systemctl daemon-reload
ssh -o StrictHostKeyChecking=no admin@server sudo systemctl enable kube-apiserver kube-controller-manager kube-scheduler
ssh -o StrictHostKeyChecking=no admin@server sudo systemctl start kube-apiserver kube-controller-manager kube-scheduler
ssh -o StrictHostKeyChecking=no admin@server sudo kubectl cluster-info --kubeconfig /tmp/admin.kubeconfig
#Configure RBAC permissions to allow kubernetes API Server to access the Kubelet API on worker nodes
ssh -o StrictHostKeyChecking=no admin@server sudo kubectl apply -f /tmp/kube-apiserver-to-kubelet.yaml --kubeconfig /tmp/admin.kubeconfig
sudo curl -k --cacert /root/kubernetes-the-hard-way/ca.crt https://server.kubernetes.local:6443/version

#Bootstrap worker nodes

for host in node-0 node-1; do
  SUBNET=$(grep $host machines.txt | cut -d " " -f 4)
  sed "s|SUBNET|$SUBNET|g" configs/10-bridge.conf > 10-bridge.conf
  sed "s|SUBNET|$SUBNET|g" configs/kubelet-config.yaml > kubelet-config.yaml
  scp 10-bridge.conf kubelet-config.yaml admin@$host:/tmp
done

for host in node-0 node-1; do
  scp \
    downloads/runc.arm64 \
    downloads/crictl-v1.28.0-linux-arm.tar.gz \
    downloads/cni-plugins-linux-arm64-v1.3.0.tgz \
    downloads/containerd-1.7.8-linux-arm64.tar.gz \
    downloads/kubectl \
    downloads/kubelet \
    downloads/kube-proxy \
    configs/99-loopback.conf \
    configs/containerd-config.toml \
    configs/kubelet-config.yaml \
    configs/kube-proxy-config.yaml \
    units/containerd.service \
    units/kubelet.service \
    units/kube-proxy.service \
    admin@$host:/tmp
done

for host in node-0 node-1; do
  ssh -o StrictHostKeyChecking=no admin@$host sudo apt-get update
  ssh -o StrictHostKeyChecking=no admin@$host sudo apt-get -y install socat conntrack ipset
  ssh -o StrictHostKeyChecking=no admin@$host sudo swapoff -a
  ssh -o StrictHostKeyChecking=no admin@$host sudo mkdir -p /etc/cni/net.d /opt/cni/bin /var/lib/kubelet /var/lib/kube-proxy /var/lib/kubernetes /var/run/kubernetes
  ssh -o StrictHostKeyChecking=no admin@$host sudo mkdir -p containerd
  ssh -o StrictHostKeyChecking=no admin@$host sudo tar -xvf crictl-v1.28.0-linux-arm.tar.gz -C /tmp
  ssh -o StrictHostKeyChecking=no admin@$host sudo tar -xvf containerd-1.7.8-linux-arm64.tar.gz -C containerd -C /tmp
  ssh -o StrictHostKeyChecking=no admin@$host sudo tar -xvf cni-plugins-linux-arm64-v1.3.0.tgz -C /opt/cni/bin/ -C /tmp
  ssh -o StrictHostKeyChecking=no admin@$host sudo mv /tmp/runc.arm64 /tmp/runc
  ssh -o StrictHostKeyChecking=no admin@$host sudo chmod +x /tmp/crictl /tmp/kubectl /tmp/kube-proxy /tmp/kubelet /tmp/runc
  ssh -o StrictHostKeyChecking=no admin@$host sudo mv /tmp/crictl /tmp/kubectl /tmp/kube-proxy /tmp/kubelet /tmp/runc /usr/local/bin/
  ssh -o StrictHostKeyChecking=no admin@$host sudo mv /tmp/containerd/bin/* /bin/
  ssh -o StrictHostKeyChecking=no admin@$host sudo mv /tmp/10-bridge.conf /tmp/99-loopback.conf /etc/cni/net.d/
  ssh -o StrictHostKeyChecking=no admin@$host sudo mkdir -p /etc/containerd/
  ssh -o StrictHostKeyChecking=no admin@$host sudo mv /tmp/containerd-config.toml /etc/containerd/config.toml
  ssh -o StrictHostKeyChecking=no admin@$host sudo mv /tmp/containerd.service /etc/systemd/system/
  ssh -o StrictHostKeyChecking=no admin@$host sudo mv /tmp/kubelet-config.yaml /var/lib/kubelet/
  ssh -o StrictHostKeyChecking=no admin@$host sudo mv /tmp/kubelet.service /etc/systemd/system/
  ssh -o StrictHostKeyChecking=no admin@$host sudo mv /tmp/kube-proxy-config.yaml /var/lib/kube-proxy/
  ssh -o StrictHostKeyChecking=no admin@$host sudo mv /tmp/kube-proxy.service /etc/systemd/system/
  ssh -o StrictHostKeyChecking=no admin@$host sudo systemctl daemon-reload
  ssh -o StrictHostKeyChecking=no admin@$host sudo systemctl enable containerd kubelet kube-proxy
  ssh -o StrictHostKeyChecking=no admin@$host sudo systemctl start containerd kubelet kube-proxy
done

#Verify node status
kubectl get nodes --kubeconfig /tmp/admin.kubeconfig