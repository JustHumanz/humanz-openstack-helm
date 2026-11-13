NS=openstack
SA=os-deployer
SECRET=os-deployer-token

SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
CA=$(kubectl get secret $SECRET -n $NS -o jsonpath='{.data.ca\.crt}')
TOKEN=$(kubectl get secret $SECRET -n $NS -o jsonpath='{.data.token}' | base64 -d)

cat > openstack-kubeconfig.yaml <<EOF
apiVersion: v1
kind: Config
clusters:
  - name: osh
    cluster:
      server: ${SERVER}
      certificate-authority-data: ${CA}
users:
  - name: ${SA}
    user:
      token: ${TOKEN}
contexts:
  - name: ${NS}-context
    context:
      cluster: osh
      user: ${SA}
      namespace: ${NS}
current-context: ${NS}-context
EOF