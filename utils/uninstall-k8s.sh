#!/bin/bash

# Uninstall script for Kubernetes and related components

echo "Stopping Kubernetes services..."
sudo systemctl stop kubelet

echo "Resetting Kubernetes..."
sudo kubeadm reset -f

echo "Removing Kubernetes directories..."
sudo rm -rf /etc/cni/net.d
sudo rm -rf /etc/kubernetes/
sudo rm -rf ~/.kube
sudo rm -rf /var/lib/etcd
sudo rm -rf /var/lib/kubelet
sudo rm -rf /var/lib/dockershim
sudo rm -rf /etc/systemd/system/kubelet.service.d
sudo rm -rf /etc/systemd/system/kubelet.service
sudo rm -rf /usr/local/bin/kubeadm /usr/local/bin/kubectl /usr/local/bin/kubelet

echo "Removing Calico if installed..."
sudo rm -rf /etc/calico
sudo kubectl delete -f https://docs.projectcalico.org/manifests/calico.yaml

echo "Removing Flannel if installed..."
sudo kubectl delete -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml

echo "Purging Kubernetes packages..."
sudo apt-get purge -y kubeadm kubectl kubelet kubernetes-cni kube*
sudo apt-get autoremove -y

echo "Removing container runtime..."
sudo apt-get purge -y containerd.io docker-ce docker-ce-cli
sudo apt-get autoremove -y
sudo rm -rf /var/lib/docker
sudo rm -rf /etc/docker
sudo rm -rf /etc/containerd

echo "Resetting iptables..."
sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F
sudo iptables -X

echo "Removing remaining Kubernetes files..."
sudo rm -rf /var/lib/cni/
sudo rm -rf /run/flannel/
sudo rm -rf /run/calico/

echo "Uninstallation complete."
