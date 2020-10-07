# Nuxeo Helm Chart

This chart aims to deploy the Nuxeo Platform in a development or staging environment, such as preview in Kubernetes.

> WARNING
The `nuxeo` chart is not production-ready by default.

By default, this chart deploys the strict minimum to have Nuxeo running:

- Single Nuxeo node.
- No persistence for binaries.
- H2 database.
- Elasticsearch embebedded.
- Chronicle Queue for the WorkManager and Nuxeo Streams.

The [values-production](./nuxeo/values-production.yaml) file provides a sample "production-like" configuration to guide people wanting to use this chart to make a "real" deployment of Nuxeo in Kubernetes, relying on:

- A Nuxeo cluster.
- Persistence for binaries.
- MongoDB with a replicaSet and persistence.
- An Elasticsearch cluster with several replicas and persistence.
- A Kafka cluster with several replicas and persistence.

This is just a sample, the subcharts referenced as dependencies need a fine-grained configuration to be suitable for production, see the available values of the related Helm charts:

- [MongoDB](https://github.com/helm/charts/blob/master/stable/mongodb/values-production.yaml)
- [PostgreSQL](https://github.com/helm/charts/blob/master/stable/postgresql/values-production.yaml)
- [Elasticsearch](https://github.com/helm/charts/blob/master/stable/elasticsearch/values.yaml)
- [Kafka](https://github.com/helm/charts/blob/master/incubator/kafka/values.yaml)
- [Redis](https://github.com/helm/charts/blob/master/stable/redis/values-production.yaml)

Currently, there is a single version of this chart for all the versions of Nuxeo.

## Chart Dependencies

### Dependency List

This chart has the following dependencies as subcharts:

- [MongoDB](https://github.com/bitnami/charts/tree/master/bitnami/mongodb)
- [PostgreSQL](https://github.com/helm/charts/tree/master/stable/postgresql)
- [Elasticsearch](https://github.com/helm/charts/tree/master/stable/elasticsearch)
- [Kafka/ZooKeeper](https://github.com/helm/charts/tree/master/incubator/kafka)
- [Redis](https://github.com/helm/charts/tree/master/stable/redis)

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

### How to Install Dependencies Without Nuxeo

To install some dependency subcharts, e.g. `mongodb` and `elasticsearch`, without installing Nuxeo:

```yaml
nuxeo:
  enable: false
tags:
  mongodb: true
  elasticsearch: true
```

This is useful to run the nuxeo unit tests in an production-like environment.

## Installing the Chart

If you enable some dependencies, make sure you download the related charts before:

```shell
helm dependency update nuxeo
```

To install the `nuxeo` chart:

```shell
helm install nuxeo --name RELEASE_NAME
```

You can override any value of the base [values.yaml](nuxeo/values.yaml) file by creating your own `myvalues.yaml` file and pass it to the `helm install` command:

```shell
helm install nuxeo --name RELEASE_NAME -f myvalues.yaml
```

You can also pass values directly to the `helm install` command:

```shell
helm install nuxeo --name RELEASE_NAME --set nuxeo.image.tag=x.y.z
```

For example, to install some packages using a Nuxeo CLID:

```shell
helm install nuxeo --name RELEASE_NAME --set nuxeo.packages=nuxeo-web-ui,nuxeo-drive --set nuxeo.clid=NUXEO_CLID
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

## Parameters

The following tables lists some of the configurable parameters of this chart and their default values. See [values.yaml](nuxeo/values.yaml) for the complete list.

| Parameter                   | Description                             | Default                                 |
| --------------------------- | --------------------------------------- | --------------------------------------- |
| `nuxeo.enable`              | Enable Nuxeo                            | `true`                                  |
| `nuxeo.image.repository`    | Nuxeo image name                        | `docker.packages.nuxeo.com/nuxeo/nuxeo` |
| `nuxeo.image.tag`           | Nuxeo image tag                         | `latest`                                |
| `nuxeo.persistence.enabled` | Enable persistence of binaries and logs | `false`                                 |

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

## Versioning and Releasing

When a pull request is merged to master:

- The [patch version](nuxeo/Chart.yaml#L4) of the chart is automatically incremented.
- The chart is released to the [Jenkins X ChartMuseum](http://chartmuseum.jenkins-x.io/index.yaml).
- A GitHub [tag](https://github.com/nuxeo/nuxeo-helm-chart/tags) is created.

See the [Jenkinsfile](Jenkinsfile) for more details.

The major and minor versions can be incremented manually.
