A Site deployed as a pod on a K8s cluster acts as a K8s ingress controller with built-in application security. It also enables the F5® Distributed Cloud Mesh (Mesh) features, such as discovery of services of the K8s cluster, publish of other Site's services on this Site, publish of this Site's discovered services on other Sites, etc.

Reference Doc: https://docs.cloud.f5.com/docs/how-to/site-management/create-k8s-site

# Overview and Goals 
1.  Build and configure a Ubuntu server with K8's. 
2.  Configure K8s site type CE ingress controller for Service Discovery
3.  Publish and secure service to public

# Features
* Automated Installation: The script installs a Kubernetes cluster with minimal user intervention.
* Security Enhancements: Includes configurations to enhance the security of your Kubernetes setup.
* Customizable Options: Users can define custom settings for the installation, ensuring the setup meets their specific requirements.

## Prerequisite

### CPU/RAM/DISK               
XC virtual CE (RHEL) - 8/32/200

Ubuntu K8s (Vanilla Install of Ubuntu 22.04) 4/16/100

XC Console - (You will need owner/admin access to a tenant)
   Permissions Needed: 
   * Perm1
   * Perm2

### HugePages 
A feature of the Linux kernel. Verify node support by running: grep HugePages /proc/meminfo

### Kubectl or Helm chart deployment?
Both are supported. This lab is built using the kubectl method. The Helm chart install method is covered here: https://docs.cloud.f5.com/docs/how-to/site-management/create-k8s-site

## Kubectl-Based Configuration Sequence

1. Create a Site token.
2. Prepare a manifest file with the parameters required for Site provisioning.
3. Deploy the Site using the kubeconfig of the K8s cluster and the manifest file.
4. Perform Site registration.
5. Verify that Distributed Cloud Services are running.

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
* Applies security best practices to the cluster configuration

### Prepare the K8s YAML manifest

The manifest file contains a YAML schema used for descriptor information to support deployment of Kubernetes for a Site. https://gitlab.com/volterra.io/volterra-ce/-/blob/master/k8s/ce_k8s.yml

From the $HOME directory on the K8s master server run the ce-k8s.sh script and provide the user-input variables. 

### Script Overview
* User Input Collection: Gathers necessary configuration details from the user, such as cluster name, latitude, longitude, site token, and the number of replicas.

* PersistentVolume Creation: Manually creates PersistentVolumes (PVs) required by the Kubernetes StatefulSet for data storage.

* Generate Kubernetes YAML Configuration: Dynamically generates a Kubernetes configuration file (ce-k8s.yaml) based on user inputs, which defines namespaces, service accounts, roles, role bindings, daemonsets, and a statefulset.

* Apply the Configuration: Deploys the generated Kubernetes resources by applying the ce-k8s.yaml configuration file to the cluster.

* Verification Instructions: Provides instructions for the user to verify that the Kubernetes resources, particularly the vp-manager pod, have been created successfully.



