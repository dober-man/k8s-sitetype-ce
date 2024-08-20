A K8s Site-type CE is a Customer Edge Service deployed as pods on a K8s cluster. This CE can act as a K8s ingress controller with built-in application security. It also enables the F5® Distributed Cloud Mesh (Mesh) features, such as discovery of services of the K8s cluster, publish of other Site's services on this Site or publish of this Site's discovered services on other Sites via an F5 XC Load Balancer.

The F5 XC Load Balancer offers an entire suite of security services providing an easy to consume and globally redundant layered security model while serving content from private K8's clusters.

Reference Doc: https://docs.cloud.f5.com/docs/how-to/site-management/create-k8s-site

# Overview and Goals 
1.  Build and configure a Ubuntu server with K8's. 
2.  Configure K8s site-type CE Ingress Controller for Service Discovery
3.  Publish and secure service to public

# Features
* Automated Installation: The scripts install a Kubernetes cluster and configure the cluster for CE services with minimal user intervention. 
* Customizable Options: Users can define custom settings for the installation, ensuring the setup meets their specific requirements.

## Prerequisite

### CPU/RAM/DISK               

Ubuntu K8s (Vanilla Install of Ubuntu 22.04) 8/16/100
<br>
(optional) 1 - Ubuntu K8s worker (Vanilla Install of Ubuntu 22.04) 8/16/100

XC Console - (You will need owner/admin access to a tenant)
   Permissions Needed: 
   * Perm1
   * Perm2

### HugePages 
A feature of the Linux kernel. Verify node support by running: grep HugePages /proc/meminfo

### Kubectl or Helm chart deployment?
Both are supported. This lab is built using the kubectl method. The Helm chart install method is covered here: https://docs.cloud.f5.com/docs/how-to/site-management/create-k8s-site

# XC Console 

Login to XC tenant – create site token:

Multicloud Network Connect -> Manage -> Site Management -> Site Tokens -> Create

# Ubuntu Server

## Install K8s
1. ssh into ubuntu-k8s server
2. Copy k8s-install.sh script into $HOME directory.
3. Give script exe permissions (chmod +x k8s-install.sh)
4. Run ./k8s-install.sh
5. Optionally deploy a worker node and in the $HOME directory run the k8s-install-worker.sh script (in utils folder), then join it to the cluster. 

### Script Overview
The k8s-install.sh script performs the following tasks:

* Installs required packages and dependencies
* Sets up Kubernetes components (e.g., kubeadm, kubelet, kubectl)
* Configures networking and security settings
* Initializes the Kubernetes cluster
* Deploys a sample NGINX Pod and exposes it as a NodePort Service. 

### Install the CE in K8s. 

The manifest file contains a YAML schema used for descriptor information to support deployment of Kubernetes for a Site. https://gitlab.com/volterra.io/volterra-ce/-/blob/master/k8s/ce_k8s.yml

This manifest is barebones and may not have all the objects required to sucessfully deploy the CE by itself. For example, Persistent volumes. By default the manifest contains static PVCs without a StorageClass, assuming an existing default StorageClass.

The ce-k8s-install.sh script specifies a local-path StorageClass for dynamic storage provisioning, ensuring compatibility with environments where default storage classes may not be present.

From the $HOME directory on the K8s master server run the ce-k8s-install.sh script and provide the user-input variables. 

### Script Overview
* Automation & Dynamic Configuration: The script version of the YAML introduces automation and dynamic generation based on user inputs (like Cluster Name, Latitude, Longitude, and Token), which simplifies deployment and reduces the chance of manual errors.
* Storage Class: The addition of a StorageClass for dynamic provisioning ensures that the StatefulSet PVCs are properly bound to volumes in diverse Kubernetes environments.
* Flexibility: The script allows the user to easily enable additional services via commented-out sections, giving more control over the deployment.

<img width="685" alt="image" src="https://github.com/user-attachments/assets/64dbc337-7af1-4247-8310-3f5420cb34cd">

## XC Console
Login in to XC Cloud Console and accept the CE registration request.

### Multicloud Network Connect -> Manage -> Site Management -> Registrations

Click Accept on the CE registration request.

<img width="1082" alt="image" src="https://github.com/user-attachments/assets/946e8c9a-cac1-40f9-9f58-2ba08706cf74">

SET OS VERSION - crt-20231010-2541

Make sure to verify the information and set the tunnel type towards the bottom: 

<img width="982" alt="image" src="https://github.com/user-attachments/assets/ccd82f80-aa0f-48e3-b4da-773b52c97475">

Click on "Sites" from the left Nav menu. Note the status of your CE cluster. It could take some time for provisioning to complete. 

<img width="1164" alt="image" src="https://github.com/user-attachments/assets/9409dc00-019a-4eaa-8d03-274039c1553d">

You will see vp-manager-0 restart and after about 90s etcd will show up
<img width="611" alt="image" src="https://github.com/user-attachments/assets/785887d9-da6a-42eb-8b05-57fdc2b3c238">





