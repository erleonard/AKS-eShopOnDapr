#PreReqs
    #Install Dapr cli
    #wget -q https://raw.githubusercontent.com/dapr/cli/master/install/install.sh -O - | /bin/bash

name="AKSeshop"
location="canadacentral"
virtualNetworkName="AKSeshopVnet"
virtualNetworkPrefix="10.0.0.0/16"
subnetName="AKSeshopSubnet"
subnetPrefix="10.0.0.0/24"
version="1.22.4"

az group create -n $name -l $location

az network vnet create -n $virtualNetworkName -g $name --address-prefixes $virtualNetworkPrefix -l $location --subnet-name $subnetName --subnet-prefixes $subnetPrefix
vnetId=$(az network vnet subnet list --vnet-name $virtualNetworkName --resource-group $name --query "[0].id" -o tsv)

az identity create -n $name -g $name
identityId=$(az identity show --name $name -g $name --query id -o tsv)

az aks create \
    --name $name \
    --resource-group $name \
    --kubernetes-version $version \
    --location $location \
    --network-plugin azure \
    --vnet-subnet-id $vnetId \
    --docker-bridge-address 172.17.0.1/16 \
    --dns-service-ip 10.240.0.10 \
    --service-cidr 10.240.0.0/24 \
    --enable-managed-identity \
    --assign-identity $identityId \
    --node-vm-size Standard_DS3_v2 \
    --node-count 3 \
    --generate-ssh-keys

az aks get-credentials -n $name -g $name --overwrite-existing

dapr init -k

helm install myeshop ./eShopOnDapr/Deploy/k8s/helm --wait

kubectl get ns
kubectl get po -o wide -n eshopondapr
kubectl describe po blazorclient-6d5889747d-j7ftk -n eshopondapr
kubectl delete po blazorclient-6d5889747d-j7ftk -n eshopondapr

kubectl apply -f - <<EOF
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: admin
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: ServiceAccount
  name: default
  namespace: eshop
EOF


kubectl port-forward blazorclient-6d5889747d-64xqb  30000:80 -n eshopondapr

helm uninstall myeshop
az group delete -n $name -y