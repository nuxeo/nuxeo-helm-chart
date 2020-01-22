# Nuxeo Helm Chart

This chart aims to deploy the Nuxeo platform in a development or staging environment, such as preview in Jenkins X.

> WARNING
The `nuxeo` chart is not production-ready. It can be configured to deploy external services, such as `MongoDB`, `PostgreSQL`, `Elasticsearch`. Yet, the subcharts referenced as dependencies often have a variant more suitable for production, for example `mongodb-replicaset` vs `mongodb` or `redis-ha` vs `redis`. Also, persistence is disabled by default in all the subcharts.

Currently, there is a single version of this chart for all the versions of Nuxeo.

## Chart Dependencies

### Dependency List

This chart has the following dependencies as subcharts:

- [MongoDB](https://github.com/helm/charts/tree/master/stable/mongodb/values.yaml)
- [Postgresql](https://github.com/helm/charts/tree/master/stable/postgresql/values.yaml)
- [Elasticsearch](https://github.com/helm/charts/tree/master/stable/elasticsearch/values.yaml)
- [Kafka/ZooKeeper](https://github.com/helm/charts/tree/master/incubator/kafka/values.yaml)
- [Redis](https://github.com/helm/charts/tree/master/stable/redis/values.yaml)

To list the chart dependencies:

```shell
helm dependency list nuxeo
```

### How to Enable/Disable Dependencies

To run Nuxeo with MongoDB, PostgreSQL, Kafka, etc., you need to enable the related dependencies.

When the chart is **deployed directly**, these dependencies are controlled by the following tags in the [values.yaml](nuxeo/values.yaml) file:

```yaml
tags:
  mongodb: false
  postgresql: false  
  elasticsearch: false
  kafka: false
  redis: false 
  
```

To enable any of these, just set the corresponding tag to `true` when installing the chart:

```shell
# deploy MongoDB along with Nuxeo
helm install nuxeo --set tags.mongodb=true
```

When the chart is **deployed as a dependency of another chart**, these dependencies are controlled by setting values such as `nuxeo.mongodb.deploy` or `nuxeo.elasticsearch.deploy` to `true`.

For example, let's take a chart using the `nuxeo` chart as a dependency, which can be the case of a `preview` chart in Jenkins X:

```yaml
dependencies:
  - name: nuxeo
    version: 0.1.0
    repository: http://jenkins-x-chartmuseum:8080
    alias: nuxeo
```

In this case, you can enable MongoDB and Elasticsearch, or any of the other supported subcharts, with the following values in the `values.yaml` file of the `preview` chart:

```yaml
nuxeo:
  mongodb:
    deploy: true
  elasticsearch:
    deploy: true
```

## Installing the Chart

If you enable some dependencies, make sure you download the related charts before:

```shell
helm dependency update nuxeo
```

To install the `nuxeo` chart:

```shell
helm install nuxeo --name RELEASE_NAME
```

You can override any value of the base [values.yaml](nuxeo/values.yaml) file by creating your own `myvalues.yaml` file and pass it to the `install` command:

```shell
helm install nuxeo --name RELEASE_NAME -f myvalues.yaml
```

You can also pass values directly to the `install` command:

```shell
helm install nuxeo --name RELEASE_NAME --set nuxeo.image.tag=10.3
```

For example, to register the instance and deploy some custom packages:

```shell
helm install nuxeo --name RELEASE_NAME --set nuxeo.packages=nuxeo-web-ui,nuxeo.studio_project=STUDIO_PROJECT,nuxeo.connect_username=CONNECT_USERNAME,nuxeo.connect_password=CONNECT_PASSWORD
```

or, using a Nuxeo CLID:

```shell
helm install nuxeo --name RELEASE_NAME --set nuxeo.packages=nuxeo-web-ui,nuxeo.clid=NUXEO_CLID
```

In the same way, you can override any subchart value by using the subchart name as a prefix:

```shell
helm install nuxeo --name RELEASE_NAME --set mongodb.persistence.enabled=true
```

To see the templates of the inatalled chart:

```shell
helm get manifest RELEASE_NAME
```

## Upgrading an Existing Deployment

For example, to enable persistence for the binaries and logs:

```shell
helm upgrade RELEASE_NAME --set nuxeo.persistence.enabled=true nuxeo
```

## Uninstalling the Chart

```shell
helm delete --purge RELEASE_NAME
```

## Using Minikube

### Install Minikube and Helm

Follow the [Minikube](https://kubernetes.io/docs/tasks/tools/install-minikube/) and [Helm](https://helm.sh/docs/intro/install/)
installation guides.

Below is the procedure for Ubuntu 18.04:

```shell
# Check VM support, the following command must output something
egrep --color 'vmx|svm' /proc/cpuinfo

# Update apt
sudo apt update && sudo apt upgrade
sudo apt install -y apt-transport-https

# Install latest VirtualBox package from https://www.virtualbox.org/wiki/Linux_Downloads

# Install kubectl
sudo snap install kubectl --classic
kubectl version

# Install Minikube
curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
chmod +x minikube
sudo mv minikube /usr/local/bin

# Install helm
sudo snap install helm --classic
```

### Initialize Minikube and Helm

```shell
# Start with a bigger VM
minikube start --cpus 4 --memory 8192 --disk-size 10g

# Enable some addons
minikube addons enable ingress
minikube addons enable storage-provisioner

# Initialize Helm
helm init --history-max 200

# Enable incubator repository needed for Kafka
helm repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator
helm repo update

# Test the dashboard
minikube dashboard
```

### Deploy Nuxeo

Try to deploy Nuxeo by installing the `nuxeo` chart:

```shell
helm install \
 --name my-nuxeo \
 --debug \
 --set nuxeo.packages=nuxeo-web-ui \
 --set tags.mongodb=true \
 --set tags.elasticsearch=true \
 --set nuxeo.ingress.enabled=true \
 --set nuxeo.clid='<insert the content of your instance.clid file in a single line replacing the new line with -->' \
  nuxeo
```

Nuxeo will be exposed on `http://$MINIKUBE IP/`.
