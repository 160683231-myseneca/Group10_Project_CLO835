#!/bin/bash
deploy_cluster(){
curl -s https://fluxcd.io/install.sh | sudo bash
aws cloud9 update-environment --environment-id $C9_PID --managed-credentials-action DISABLE
rm -vf ${HOME}/.aws/credentials
  
echo "Enter AWS Credentials (end with an empty line):"
AWS_CREDS=""

while IFS= read -r line; do
    [[ -z $line ]] && break 
    AWS_CREDS+="$line"$'\n'
done

cat <<-EOF >> ~/.aws/credentials
$AWS_CREDS
EOF

echo "Starting EKS cluster..."
eksctl create cluster -f eks_config.yaml
}



init_cluster() {

echo "Initialising cluster..."
aws eks update-kubeconfig --name clo835-final --region us-east-1
eksctl utils write-kubeconfig --cluster=clo835-final --region us-east-1

echo "Log into ECR"
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 636276102612.dkr.ecr.us-east-1.amazonaws.com

echo "Install Ingress Controller..."
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.1.1/deploy/static/provider/aws/deploy.yaml

echo "Install Metrics service Controller..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.7.1/components.yaml

echo "Installing hey package to help run infinite loops"
wget https://hey-release.s3.us-east-2.amazonaws.com/hey_linux_amd64
chmod +x hey_linux_amd64
sudo mv hey_linux_amd64 /usr/local/bin/hey

echo "Install CSI driver to the cluster clo835-final in the region us-east-1"
eksctl create addon --name aws-ebs-csi-driver --cluster clo835-final --region us-east-1

# echo "Creating aws credentials..."  
# kubectl create secret generic aws-creds --from-literal=awsAccessKeyId=$aws_access_key_id --from-literal=awsSecretAccessKey=$aws_secret_access_key --from-literal=awsSessionToken=$aws_session_token -n final
  
}


start_deployment() {
echo "Starting deployment..."

echo "Creating namespaces..."
kubectl create ns final
 
echo "Enter MySQL root password:"
read -s MYSQL_ROOT_PASSWORD
  
kubectl create secret generic mydb-secret --from-literal=password="$MYSQL_ROOT_PASSWORD" --type=kubernetes.io/basic-auth -n final 

echo "Deploying backend..."
kubectl apply -f k8manifest/backend-pv.yaml
sleep 30s
kubectl apply -f k8manifest/backend-deployment.yaml -n final
kubectl apply -f k8manifest/backend-service.yaml -n final

sleep 60s
echo "Deploying frontend..."
kubectl apply -f k8manifest/frontend-configmap.yaml -n final
CONFIG_HASH=$(kubectl get configmap myapp-config -n final -o yaml | sha256sum | cut -d' ' -f1)  
echo "ConfigMap Hash: $CONFIG_HASH"
kubectl apply -f k8manifest/frontend-deployment.yaml -n final
kubectl apply -f k8manifest/frontend-service.yaml -n final
}

lb_ingress() {
echo "deploying ingress..."
kubectl apply -f k8manifest/ingress.yaml -n final
kubectl get ingress myapp-ingress -n final -o jsonpath="{.status.loadBalancer.ingress[*].hostname}" && echo""
}


update_config() {
CONFIG_HASH=$(kubectl get configmap myapp-config -n final -o yaml | sha256sum | cut -d' ' -f1)  
echo "ConfigMap Hash before update: $CONFIG_HASH"
kubectl apply -f k8manifest/frontend-configmap.yaml -n final
CONFIG_HASH=$(kubectl get configmap myapp-config -n final -o yaml | sha256sum | cut -d' ' -f1)  
echo "ConfigMap Hash after update: $CONFIG_HASH"
kubectl patch deployment myapp -n final -p "{\"spec\":{\"template\":{\"metadata\":{\"annotations\":{\"configHash\":\"${CONFIG_HASH}\"}}}}}"
sleep 10s
kubectl get pods -n final
}

scale_hpa() {
echo "Creating services..."
kubectl apply -f k8manifest/service-account.yaml -n final
kubectl apply -f k8manifest/role.yaml -n final
kubectl apply -f k8manifest/role-binding.yaml -n final
kubectl apply -f k8manifest/hpa.yaml -n final
  
echo "Checking if Metrics Server is running..."  
kubectl get pods -n kube-system | grep metrics-server

echo "Calling website 1000 times using hey tool..."
INGRESS_FQDN=$(kubectl get ingress myapp-ingress -n final -o jsonpath="{.status.loadBalancer.ingress[*].hostname}")
hey -n 1000 -c 100 http://$INGRESS_FQDN
 
sleep 15s 
echo "Getting CPU usage of pods..."  
kubectl top pods -n final

sleep 15s 
echo "Checking for pod scaling..."
kubectl get pods -n final
  
}


deploy_helm() {


# curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
# chmod 700 get_helm.sh
# ./get_helm.sh

# wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.18.0/kubeseal-0.18.0-linux-amd64.tar.gz
# tar xfz kubeseal-0.18.0-linux-amd64.tar.gz
# sudo install -m 755 kubeseal /usr/local/bin/kubeseal

# kubectl rollout restart deployment/myapp -n final
# kubectl delete ingressclass nginx
# kubectl delete ingress --all -n final
# kubectl delete configmaps --all -n final
# kubectl delete services --all -n final
# kubectl delete serviceacccounts --all -n final
# kubectl delete secrets --all -n final
# kubectl delete sealedsecrets --all -n final
# kubectl delete roles --all -n final
# kubectl delete rolebindings --all -n final
# kubectl delete pvc --all -n final
# kubectl delete all --all -n final
# kubectl delete namespace final



echo "Creating namespaces..."
kubectl create ns project

echo "Creating sealed secrets controller..."
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm install sealed-secrets sealed-secrets/sealed-secrets -n kube-system --set-string fullnameOverride=sealed-secrets-controller 


helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
# helm install nginx-ingress ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace --set controller.service.type=LoadBalancer --set controller.admissionWebhooks.enabled=false


echo "Creating sealed secrets..."
kubectl create secret generic mydb-secret --namespace project --dry-run=client --from-literal=password=mytopsecret -o yaml | kubeseal --controller-name=sealed-secrets-controller --controller-namespace=kube-system --scope cluster-wide --format yaml| kubectl apply -f -

helm install web k8chart/ --values k8chart/values.yaml
helm upgrade web k8chart/ --values k8chart/values.yaml
}

delete_cluster() {
echo "Deleting cluster..."
eksctl delete cluster -f eks_config.yaml 
}

echo "Select an action:"
echo "1. Start EKS Cluster"
echo "2. Initialise cluster"
echo "3. Deploy App"
echo "4. Deploying ingress"
echo "5. Update configMap file with new picture"
echo "6. Autoscaling using HPA and service account"
echo "7. Deploy using Helm"
read -p "Enter your choice: " choice

case "$choice" in
  "1")
    deploy_cluster
    ;;
  "2")
    init_cluster
    ;;
  "3")
    start_deployment
    ;;
  "4")
    lb_ingress
    ;;
  "5")
    update_config
    ;;
  "6")
    scale_hpa
    ;;
  "7")
    deploy_helm
    ;;
  *)
    echo "Invalid choice. Please select 1 - 7."
    exit 1
    ;;
esac

exit 0
