#!/bin/bash
set -e
###############################################################
# Script Parameters                                           #
###############################################################

while getopts n:e: option
do
    case "${option}"
    in
    n) NAME=${OPTARG};;
    e) ENVIRONMENT=${OPTARG};;
    esac
done

if [ -z "$NAME" ]; then
    echo "-n is a required argument - Name"
    exit 1
fi
if [ -z "$ENVIRONMENT" ]; then
    echo "-e is a required argument - Environment (dev, prod)"
    exit 1
fi

###############################################################
# Script Begins                                               #
###############################################################

RESOURCE_GROUP_NAME=${NAME}${ENVIRONMENT}
ARM_SUBSCRIPTION_ID=$(az account show --query id --out tsv)
az account set --subscription $ARM_SUBSCRIPTION_ID

# get kubeconfig
az aks get-credentials --admin --name $RESOURCE_GROUP_NAME-aks --resource-group $RESOURCE_GROUP_NAME

# add helm repo to acr
az configure --defaults acr=${RESOURCE_GROUP_NAME}
az acr helm repo add

az acr build -t devops-agent:latest ./agents

kubectl apply -f ../config/helm-rbac.yml
kubectl apply -f ../config/pod-security.yml
kubectl apply -f ../config/kured.yml

# deploy tiller
mv ../helm-certs.zip .
unzip helm-certs.zip

set +e ## ignore errors if these exist already
kubectl create namespace tiller-world
kubectl create namespace ingress
set -e

helm init --force-upgrade --tiller-tls --tiller-tls-cert ./tiller.cert.pem --tiller-tls-key ./tiller.key.pem --tiller-tls-verify --tls-ca-cert ca.cert.pem --tiller-namespace=tiller-world --service-account=tiller

cp ca.cert.pem ~/.helm/ca.pem
cp helm.cert.pem ~/.helm/cert.pem
cp helm.key.pem ~/.helm/key.pem

rm -rf *.pem && rm -rf *.zip

# Create a namespace for your ingress resources
kubectl create namespace ingress

# Use Helm to deploy an NGINX ingress controller
helm install stable/nginx-ingress \
    --namespace ingress \
    --set controller.replicaCount=2 \
    --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux

# kubectl get service captureorder -o jsonpath="{.status.loadBalancer.ingress[*].ip}" -w
# kubectl get svc  -n ingress    ingress-nginx-ingress-controller -o jsonpath="{.status.loadBalancer.ingress[*].ip}"


#!/bin/bash

# Public IP address
# IP="<PUBLIC_IP_OF_THE_K8S_CLUSTER_ON_AKS>"

# # Name to associate with public IP address
# DNSNAME="<DESIRED_FQDN_PREFIX>" // FQDN will then be DNSNAME.ZONE.cloudapp.azure.com

# # Get resource group and public ip name
# RESOURCEGROUP=$(az network public-ip list --query "[?ipAddress!=null]|[?contains(ipAddress, '$IP')].[resourceGroup]" --output tsv)
# PIPNAME=$(az network public-ip list --query "[?ipAddress!=null]|[?contains(ipAddress, '$IP')].[name]" --output tsv)

# # Update public ip address with dns name
# az network public-ip update --resource-group $RESOURCEGROUP --name  $PIPNAME --dns-name $DNSNAME

# # Public IP address of your ingress controller
# IP="40.121.63.72"

# # Name to associate with public IP address
# DNSNAME="demo-aks-ingress"

# # Get the resource-id of the public ip
# PUBLICIPID=$(az network public-ip list --query "[?ipAddress!=null]|[?contains(ipAddress, '$IP')].[id]" --output tsv)

# # Update public ip address with DNS name
# az network public-ip update --ids $PUBLICIPID --dns-name $DNSNAME


 
# # Install the CustomResourceDefinition resources separately
# kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.8/deploy/manifests/00-crds.yaml

# # Create the namespace for cert-manager
# kubectl create namespace cert-manager

# # Label the cert-manager namespace to disable resource validation
# kubectl label namespace cert-manager certmanager.k8s.io/disable-validation=true

# # Add the Jetstack Helm repository
# helm repo add jetstack https://charts.jetstack.io

# # Update your local Helm chart repository cache
# helm repo update

# # Install the cert-manager Helm chart
# helm install \
#   --name cert-manager \
#   --namespace cert-manager \
#   --version v0.8.1 \
#   jetstack/cert-manager

# kubectl apply -f cluster-issuer.yaml

