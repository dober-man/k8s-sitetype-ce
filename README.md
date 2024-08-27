A K8s Site-type CE is a Customer Edge Service deployed as pods on a K8s cluster. This CE can act as a K8s ingress controller with built-in application security. It also enables the F5® Distributed Cloud Mesh (Mesh) features, such as discovery of services of the K8s cluster, publish of other Site's services on this Site or publish of this Site's discovered services on other Sites via an F5 XC Load Balancer.

The F5 XC Load Balancer offers an entire suite of security services providing an easy to consume and globally redundant layered security model while serving content from private K8's clusters.

Reference Doc: https://docs.cloud.f5.com/docs/how-to/site-management/create-k8s-site

# Overview and Goals 
1.  Build and configure a Ubuntu server with K8's. 
2.  Configure K8s site-type CE Ingress Controller for Service Discovery
3.  Publish and secure service to public

# Features
* Automated Installation: The scripts install a Kubernetes cluster, configure the cluster for CE services and setup of Auth with minimal user intervention. 
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

### Script Overview
The manifest file necessary to deply a K8s sitetype CE contains a YAML schema used for descriptor information to support deployment of Kubernetes for a Site. https://gitlab.com/volterra.io/volterra-ce/-/blob/master/k8s/ce_k8s.yml

This manifest is barebones and may not have all the objects required to sucessfully deploy the CE by itself. For example, Persistent volumes. By default the manifest contains static PVCs without a StorageClass, assuming an existing default StorageClass.

The ce-k8s-install.sh script specifies a local-path StorageClass for dynamic storage provisioning, ensuring compatibility with environments where default storage classes may not be present.

From the $HOME directory on the K8s master server run the ce-k8s-install.sh script and provide the user-input variables. Don't foget to give the script +x permissions. 

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

You should see vp-manager-0 go through several status updates. 

After accepting the registration in XC Console, from the CLI you will see vp-manager-0 restart and eventually the etcd pod will show up followed by prometheus and ver-0 pods. 

<img width="1301" alt="image" src="https://github.com/user-attachments/assets/cee5b782-957c-4560-9c8a-0610ec4d9a1e">

Please wait until all pods are "Running" before moving to the next step. 

### Pods, Services & Networking Overview

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
<br>
Type: ClusterIP
<br>
ClusterIP: Yes
<br>
Ports: 65341/TCP, 65341/UDP
<br>
Role: Exposes a statsd exporter for Prometheus, which collects metrics in the statsd format.

pushgateway
<br>
Type: ClusterIP
<br>
ClusterIP: Yes
<br>
Port: 65220/TCP
<br>
Role: Provides an endpoint for the Prometheus Pushgateway, used to push metrics from short-lived jobs to Prometheus.

ver
<br>
Type: NodePort
<br>
ClusterIP: Yes
<br>
Ports: Various ports mapped to high NodePort values, enabling external access to the VER component on these ports.
<br>
Role: Exposes the Volterra Edge Router to external networks through specific NodePorts.

vpm
<br>
Type: NodePort
<br>
ClusterIP: Yes
<br>
Port: 65003/TCP
<br>
Role: Exposes the Volterra Platform Manager to external networks through a specific NodePort.

## Networking Overview:

* ClusterIP Services: These are accessible only within the Kubernetes cluster. They are typically used to facilitate internal communication between services and pods.

* Headless Service (etcd): The etcd service does not have a ClusterIP and instead directly resolves to the individual pod IPs of the StatefulSet, enabling clients to interact with each pod directly.

* NodePort Services (ver, vpm): These services are exposed to external traffic on specific ports of each node's IP address. NodePorts enable external clients to access these services through any of the cluster nodes on a specific port.


## Service Discovery
In the VE CE service discovery lab setup found here: https://github.com/dober-man/ve-ce-secure-k8s-gw we used Kubeconfig as the authentication mechanism for Service Discovery in the K8s cluster. 

In this setup we are going to use the alternate method of TLS Parameters for HTTP REST to provide an example of that method. 

## TLS Parameters for HTTP REST

### Create a Service Discovery

Multicloud App Connect -> Manage -> Service Discovery -> Add Discovery

Name: my-sd

Virtual-Site or Site or Network: Site
<br>
Reference: - [choose your CE site]

Network Type: Site Local Network
<br>
Discovery Method: K8s Discovery Configuration

<img width="925" alt="image" src="https://github.com/user-attachments/assets/04db4a77-9287-4594-a8fc-71071be07100">


Click on "Configure" under K8S Discovery Configuration

Access credentials:<br>
Select Kubernetes Credentials: TLS Parameters for HTTP REST

API Server and Port: [choose your k8s master-node ip]:6443<br>
TLS Parameters: [Configure]<br>
<img width="888" alt="image" src="https://github.com/user-attachments/assets/ed0e5fe0-ac32-41a5-9a8e-2e8fbc79ed4e">

## You will be able to configure these settings based on the set_xc_auth script output you are about to run. 

Copy the set_xc_auth script to the $HOME directory, give it +x perms and run it. 

This script is useful for setting up a new Kubernetes user with certificate-based authentication, configuring their kubeconfig file, and granting them administrative access to the cluster. Here's a brief overview of its main functionality:

### User Prompts:

The script begins by prompting the user to enter a desired username (which will be used as the Common Name in the certificate) and the path for the kubeconfig file (defaulting to ~/.kube/config).


#### Directory Setup:
It defines a destination directory (~/certs) where the generated certificates and keys will be stored, and creates this directory if it doesn't already exist.

#### Certificate Authority (CA) Certificate:
The script copies the Kubernetes CA certificate (ca.crt) from /etc/kubernetes/pki/ to the destination directory.

#### Private Key Generation:
A new private key (client.key) is generated using OpenSSL and saved in the destination directory.

#### Certificate Signing Request (CSR):
A CSR (client.csr) is generated using the private key, with the subject set to the entered username.

#### Client Certificate Generation:
The script signs the CSR using the Kubernetes CA to create a client certificate (client.crt), which is valid for 365 days.

#### Verification:

It lists the generated files and verifies the contents of both the CA certificate and the client certificate by displaying their details.

#### Kubeconfig Setup:

The script configures the kubeconfig file at the specified path by setting the cluster, user credentials, and context using the generated certificates and keys. It points the kubeconfig file to the Kubernetes API server (https://master-node:6443).

####  Cluster Role Binding:
It creates a ClusterRoleBinding, granting the user cluster-admin privileges (Note: this is generally not recommended for production environments due to security concerns).

#### Context Configuration:

The script sets the context in the kubeconfig file to use the newly created user and cluster.

#### Final Output:

The script confirms that the kubeconfig file has been successfully set up with the new client certificate.
The output will be in the $HOME/certs folder. 

<img width="397" alt="image" src="https://github.com/user-attachments/assets/82d5556d-498e-4e3e-8e4e-6e34eb11c426">

### Return to XC Console and enter your TLS Server parameters
<br>
Note: For this setup we will leave the SNI blank.
Copy the appropriate data from the CA and client cert and key files from the $HOME/certs directory. 

<img width="986" alt="image" src="https://github.com/user-attachments/assets/29c7f824-238c-4f75-b664-71091a861c00">

The client private key will be blindfolded. More info here: https://docs.cloud.f5.com/docs-v2/multi-cloud-network-connect/how-to/adv-security/blindfold-tls-certs

<img width="772" alt="image" src="https://github.com/user-attachments/assets/7a818da5-91e8-4849-9ff0-5d12aea3f527">

Click "Apply" 

<img width="912" alt="image" src="https://github.com/user-attachments/assets/fc0bf24e-1b11-42de-a6e9-c6ca9cd34ae1">

Save and Exit

<img width="1180" alt="image" src="https://github.com/user-attachments/assets/63737700-67e6-4e0a-968a-dec804187765">


Hit "Refresh" in XC Console and you should see 1 discovered service. 
<img width="1067" alt="image" src="https://github.com/user-attachments/assets/3cf3660c-463c-4cba-8246-711c5a6cb007">

## Deploy a Second Service in K8s (optional but demonstrates how quickly SD works on the XC side....instant)
kubectl create deployment nginx2 --image=nginxdemos/hello <br>
kubectl expose deployment nginx2 --port=81 --target-port=81 --type=NodePort

Hit "Refresh" in XC Console and you should now see 2 discovered services. 
<img width="743" alt="image" src="https://github.com/user-attachments/assets/74bcf84e-969d-4d4d-be04-c73250b175d8">

Click on the Service Hyperlink and note the service names for the services. These will be referenced in the origin pool when we publish this service. 

<img width="1271" alt="image" src="https://github.com/user-attachments/assets/2c85e4e4-3440-4ee6-8f81-7edb591aa6b6">

# Publish the service

## Create Origin Objects

Create Origin Servers and Pool with Discovered Service: 

#### Multicloud App Connect -> Manage -> Load Balancers -> Origin Pools -> Add Origin Pool 

Define the Origin Servers (click Add Item) and use the screenshot to fill in the config. 
<img width="1206" alt="image" src="https://github.com/user-attachments/assets/8010b034-f8b9-44c3-b6f8-8de6353b6c8b">

Define the Pool Definitions as shown in the screenshot. 
<img width="885" alt="image" src="https://github.com/user-attachments/assets/e9bfc1ed-2f3c-4e0a-9018-daa19b338122">
<img width="900" alt="image" src="https://github.com/user-attachments/assets/02710b3b-80cf-4c64-8de3-edb82997b6b4">


Note: You must specify port 80 for the origin pool (even though it is technically dynamic at the Node/pod level). Remember all traffic being sent between the XC cloud and CE is natively encrypted so this is all tunneled until the last hop to the pod. In our test scenario it will look like this: User-->80-->VIP-->443-->CE-->80--Origin Pool --> (Nodeport).  

## Load Balancer

Create http load balancer:

#### Multicloud App Connect -> Manage -> Load Balancers -> http load balancer

Use the screenshot to configure the load balancer: 

<img width="886" alt="image" src="https://github.com/user-attachments/assets/da37c504-5f87-40ee-8725-1ec4024457c0">


For the WAF policy - Create a new policy called "blocking-policy", put it in blocking mode and take all defaults

<img width="889" alt="image" src="https://github.com/user-attachments/assets/aca0998a-78ce-40e6-b9de-f9981e3189c3">

For everything below the WAF policy, take all the defaults but note all of the other layered security features can be added.

Click "Save and Exit" 

Click the "Actions buttons" under load balancer name and go to "Manage Configuration".
<img width="1088" alt="image" src="https://github.com/user-attachments/assets/341f5cd7-29a7-48b0-80a3-21eb77681ee4">

Click the JSON tab and note your IP address. 
<img width="874" alt="image" src="https://github.com/user-attachments/assets/6c883512-8225-48b0-8cd3-6f4f02c04e8c">

On your local/test machine create a host file entry pointing nginx.example.com to that IP address and test your access to http://nginx.example.com.

<img width="776" alt="image" src="https://github.com/user-attachments/assets/bcfa83a9-0308-4921-9fa8-3e66924c9d73">

## Verify the WAF
run http://nginx.example.com/<script>

<img width="673" alt="image" src="https://github.com/user-attachments/assets/c6fad06f-be4e-4bd2-8742-b45cb989130f">




