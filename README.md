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

### Kubectl or Helm chart CE deployment?
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

## Install the CE in K8s. 

### Script Features
* Automation & Dynamic Configuration: The script version of the YAML introduces automation and dynamic generation based on user inputs (like Cluster Name, Latitude, Longitude, and Token), which simplifies deployment and reduces the chance of manual errors.
* Storage Class: The addition of a StorageClass for dynamic provisioning ensures that the StatefulSet PVCs are properly bound to volumes in diverse Kubernetes environments.
* Flexibility: The script allows the user to easily enable additional services via commented-out sections, giving more control over the deployment.

### Script Overview
The manifest file contains a YAML schema used for descriptor information to support deployment of Kubernetes for a Site. https://gitlab.com/volterra.io/volterra-ce/-/blob/master/k8s/ce_k8s.yml

This manifest is barebones and may not have all the objects required to sucessfully deploy the CE by itself. For example, Persistent volumes. By default the manifest contains static PVCs without a StorageClass, assuming an existing default StorageClass.

The ce-k8s-install.sh script specifies a local-path StorageClass for dynamic storage provisioning, ensuring compatibility with environments where default storage classes may not be present.

From the $HOME directory on the K8s master server run the ce-k8s-install.sh script and provide the user-input variables. 
As the script completes it will suggest running: watch kubectl get pods -n ves-system -o=wide

You want to make sure you see the following pods "Running" before proceeding. 

<img width="1306" alt="image" src="https://github.com/user-attachments/assets/54eed191-e668-4167-801f-013bdace5a70">


## XC Console
Login in to XC Cloud Console and accept the CE registration request.

### Multicloud Network Connect -> Manage -> Site Management -> Registrations

Click Accept on the CE registration request.

<img width="1082" alt="image" src="https://github.com/user-attachments/assets/946e8c9a-cac1-40f9-9f58-2ba08706cf74">

Currently, you will need to static set the software OS version to crt-20231010-2541. This should be addressed in future updates. 
<img width="885" alt="image" src="https://github.com/user-attachments/assets/695f6e57-324a-43b3-9c70-438499871960">

You will also set the Site to Site Tunnel Type. In this setup we are using SSL. 
<img width="890" alt="image" src="https://github.com/user-attachments/assets/690be695-166b-4681-bad6-3fd250b3f108">



Click "Save and Exit" to accept the registration request and then click on "Sites" from the left Nav menu. Note the status of your CE cluster. It could take some time for provisioning to complete. 

<img width="1164" alt="image" src="https://github.com/user-attachments/assets/9409dc00-019a-4eaa-8d03-274039c1553d">

Keep an eye on: watch kubectl get pods -n ves-system -o=wide

You should see vp-manager-0 go through several statuses. 

After a minute or two, you will see vp-manager-0 restart and eventually the etcd pod will show up followed by prometheus and ver-0 pods. 

<img width="1301" alt="image" src="https://github.com/user-attachments/assets/cee5b782-957c-4560-9c8a-0610ec4d9a1e">

Please wait until all pods are "Running" before moving to the next step. 

Pods, Services & Networking Overview

Pods: 

etcd-0 
<br>
Containers: 2
<br>
Role: This pod is part of the etcd cluster, which is the key-value store used by XC Kubernetes to store all cluster data. This is different than the K8s etcd running in the kube-system namespace. 

prometheus
<br>
Containers: 5
<br>
Role: This pod is running Prometheus, a monitoring and alerting toolkit commonly used to gather metrics and monitor the Kubernetes cluster.

ver-0
<br>
Containers: 17
<br>
Role: Volterra Edge Router (VER), a component of F5 Distributed Cloud Services used for networking and security functions.


volterra-ce-init-hxgmm
<br>
Containers: 1
<br>
Role: This is an initialization pod for Volterra Control Edge (CE), possibly used to initialize or bootstrap the environment.

vp-manager-0
<br>
Containers: 1
<br>
Role: Volterra Platform Manager (VP Manager), which manages and monitors the overall environment.

### Services 
<br>
Services provide a stable network endpoint for a set of Pods and enable the Pods to communicate with each other or with external services. 

Here are the details of the Services in the ves-system namespace:

etcd
Type: ClusterIP (internal-only service).
<br>
ClusterIP: None (headless service, allowing direct access to individual pods).
<br>
Ports: 2379/TCP (client communication), 2380/TCP (peer communication), 65535/TCP.
<br>
Role: Provides network endpoints for etcd clients and peers.

etcd-0
<br>
Type: ClusterIP (internal-only service)
<br>
ClusterIP: Yes
<br>
Ports: Same as the etcd service
<br>
Role: This service specifically targets the etcd-0 pod, which is part of the etcd StatefulSet.

prometheus
<br>
Type: ClusterIP
<br>
ClusterIP: Yes
<br>
Port: 32222/TCP
<br>
Role: Provides a stable network endpoint for accessing Prometheus metrics.

prometheus-statsd
Type: ClusterIP
ClusterIP: Yes
Ports: 65341/TCP, 65341/UDP
Role: Exposes a statsd exporter for Prometheus, which collects metrics in the statsd format.

pushgateway
Type: ClusterIP
ClusterIP: Yes
Port: 65220/TCP
Role: Provides an endpoint for the Prometheus Pushgateway, used to push metrics from short-lived jobs to Prometheus.

ver
Type: NodePort
ClusterIP: Yes
Ports: Various ports mapped to high NodePort values, enabling external access to the VER component on these ports.
Role: Exposes the Volterra Edge Router to external networks through specific NodePorts.

vpm
Type: NodePort
ClusterIP: Yes
Port: 65003/TCP
Role: Exposes the Volterra Platform Manager to external networks through a specific NodePort.

Networking Overview:

ClusterIP Services: These are accessible only within the Kubernetes cluster. They are typically used to facilitate internal communication between services and pods.

Headless Service (etcd): The etcd service does not have a ClusterIP and instead directly resolves to the individual pod IPs of the StatefulSet, enabling clients to interact with each pod directly.

NodePort Services (ver, vpm): These services are exposed to external traffic on specific ports of each node's IP address. NodePorts enable external clients to access these services through any of the cluster nodes on a specific port.


# Service Discovery
In the VE CE service discovery lab setup found here: https://github.com/dober-man/ve-ce-secure-k8s-gw we used Kubeconfig as the authentication mechanism for Service Discovery in the K8s cluster. 

In this setup we are going to use the alternate method of TLS Parameters for HTTP REST to provide an example of that method. 

## TLS Parameters for HTTP REST

Create a Service Discovery.

Multicloud App Connect -> Manage -> Service Discovery -> Add Discovery
Name: my-sd

Virtual-Site or Site or Network: Site

Reference: - [choose your CE site]

Network Type: Site Local Network

Discovery Method: K8s Discovery Configuration

[SCREENSHOT]

Click on "Configure" under K8S Discovery Configuration

Access credentials:
Select Kubernetes Credentials: TLS Parameters for HTTP REST






