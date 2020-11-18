
# create namespaces
kubectl create ns test-nuxeo-external-services
kubectl create ns test-nuxeo

# add Helm chart repositories
# mongodb / kafka
helm repo add bitnami https://charts.bitnami.com/bitnami
# elasticsearch
helm repo add elastic https://helm.elastic.co/
# nuxeo
helm repo add nuxeo https://chartmuseum.platform.dev.nuxeo.com/

# install external services in the test-nuxeo-external-services namespace, with:
# - release name = chart name
# - a fixed version
# - the minimum customization for now
helm repo update
helm install mongodb bitnami/mongodb \
  --version=7.14.2 \
  --namespace=test-nuxeo-external-services \
  --values=values-mongodb.yaml

# helm install postgresql bitnami/postgresql \
#   --version=9.8.4 \
#   --namespace=test-nuxeo-external-services \
#   --values=values-postgresql.yaml

helm install elasticsearch elastic/elasticsearch \
  --version=7.9.2 \
  --namespace=test-nuxeo-external-services \
  --values=values-elasticsearch.yaml

helm install kafka bitnami/kafka \
  --version=11.8.8 \
  --namespace=test-nuxeo-external-services \
  --values=values-kafka.yaml

# wait for external services to be ready
kubectl rollout status deployment mongodb \
  --namespace=test-nuxeo-external-services \
  --timeout=3m

kubectl rollout status statefulset elasticsearch-master \
  --namespace=test-nuxeo-external-services \
  --timeout=5m

kubectl rollout status statefulset kafka \
  --namespace=test-nuxeo-external-services \
  --timeout=3m

# tmp: build nuxeo chart from the current branch
helm package nuxeo

# install nuxeo in the test-nuxeo namespace, with:
# - release name = chart name = nuxeo
# - a fixed version of the chart
# - the 11.x image = latest build = currently 11.4.28
# - customized values to enable external services: mongodb, elasticsearch, kafka
helm install nuxeo nuxeo/nuxeo \
  --version=2.0.0 \
  --namespace=test-nuxeo \
  --set=nuxeo.image.tag=11.x \
  --set=nuxeo.image.pullPolicy=Always \
  --values=values-nuxeo.yaml

# cleanup
helm uninstall kafka -n test-nuxeo-external-services
helm uninstall elasticsearch -n test-nuxeo-external-services
# helm uninstall postgresql -n test-nuxeo-external-services
helm uninstall mongodb -n test-nuxeo-external-services
helm uninstall nuxeo -n test-nuxeo

kubectl delete ns test-nuxeo
kubectl delete ns test-nuxeo-external-services
