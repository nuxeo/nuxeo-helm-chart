# Nuxeo Helm Chart

This chart bootstraps a [Nuxeo](https://github.com/nuxeo/nuxeo-lts/tree/2023/docker/nuxeo) deployment on a [Kubernetes](https://kubernetes.io/) cluster using the [Helm](https://helm.sh/) package manager.

> WARNING
The `nuxeo` chart is not production-ready by default.
It suits for a development or staging environment such as preview.

Currently, there is a single version of this chart for all the versions of Nuxeo.

The code samples below rely on the [Helm 3](https://helm.sh/docs/helm/helm/) command line.

## Scope

By default, this chart deploys the strict minimum to have Nuxeo running with:

- [emptyDir](https://kubernetes.io/docs/concepts/storage/volumes/#emptydir) volume for binaries.
- H2 database.
- Elasticsearch embedded.
- Chronicle Queue for the WorkManager and Nuxeo Streams.

To make a "real" deployment of Nuxeo in Kubernetes, you can have a look at:

- The different parameters in the [values.yaml](nuxeo/values.yaml) file.
- The [Full Deployment](#full-deployment) section.

## TL;DR

```shell
helm repo add nuxeo https://packages.nuxeo.com/repository/helm-releases-public/
helm install my-release nuxeo/nuxeo
```

## Installing the Chart

The `nuxeo` chart can be installed either:

- Remotely, from the Nuxeo chart repository.
- Locally, from a checkout of this GitHub repository.

### Remote Installation

To install the chart from the Nuxeo chart respository, add this repository to the Helm configuration:

```shell
helm repo add nuxeo https://packages.nuxeo.com/repository/helm-releases-public/
```

Then, use `nuxeo/nuxeo` as a replacement of `NUXEO_CHART` in the commands below.

### Local Installation

To install the chart from a checkout of this GitHub repository, use `nuxeo` as a replacement of `NUXEO_CHART` in the commands below.

### Installation Command Sample

To install the `nuxeo` chart:

```shell
helm install RELEASE_NAME NUXEO_CHART
```

You can override any value of the base [values.yaml](nuxeo/values.yaml) file by creating your own `myvalues.yaml` file and pass it to the `helm install` command:

```shell
helm install RELEASE_NAME NUXEO_CHART --values=myvalues.yaml
```

You can also pass values directly to the `helm install` command:

```shell
helm install RELEASE_NAME NUXEO_CHART --set nuxeo.image.tag=x.y.z
```

For example, to install some packages using a Nuxeo CLID:

```shell
helm install RELEASE_NAME NUXEO_CHART --set nuxeo.packages=nuxeo-web-ui,nuxeo-drive --set nuxeo.clid=NUXEO_CLID
```

To see the templates of the installed release:

```shell
helm get manifest RELEASE_NAME
```

## Upgrading an Existing Deployment

For example, to pull another nuxeo image:

```shell
helm upgrade RELEASE_NAME NUXEO_CHART --set image.tag=2023.x
```

## Uninstalling the Chart

```shell
helm uninstall RELEASE_NAME
```

## Parameters

The following tables lists some of the configurable parameters of this chart and their default values. See [values.yaml](nuxeo/values.yaml) for the complete list.

| Parameter                   | Description                             | Default                                         |
| --------------------------- | --------------------------------------- | ----------------------------------------------- |
| `nuxeo.image.repository`    | Nuxeo image name                        | `docker-private.packages.nuxeo.com/nuxeo/nuxeo` |
| `nuxeo.image.tag`           | Nuxeo image tag                         | `2023`                                          |

## Versioning and Releasing

When a pull request is merged to master:

- The [patch version](nuxeo/Chart.yaml#L4) of the chart is automatically incremented.
- The chart is released to the Nuxeo's [ChartMuseum](https://packages.nuxeo.com/repository/helm-releases-public/).
- A GitHub [tag](https://github.com/nuxeo/nuxeo-helm-chart/tags) is created.

See the [Jenkinsfile](./Jenkinsfile) for more details.

The major and minor versions can be incremented manually.

## Full Deployment

To deploy Nuxeo along with MongoDB, Elasticsearch and Kafka, one way is to use [Helmfile](https://github.com/roboll/helmfile) to deploy multiple charts. You can have a look at this [helmfile](./examples/helmfile.yaml) sample.

To run it, you need to:

- Install the [helmfile](https://github.com/roboll/helmfile#installation) command line.
- Clone this repository or download the [examples](./examples) directory.
- In the `examples` directory, run:

```shell
helmfile --namepsace=NAMESPACE sync
```

`NAMESPACE` is the target Kubernetes namespace for the various Helm releases.

The parameters of the `nuxeo` chart, such as the Nuxeo image, can be configured in the [values-nuxeo.yaml.gotmpl](./examples/values-nuxeo.yaml.gotmpl) file.

The parameters of the `mongodb`, `elasticsearch` and `kafka` charts can be configured in the [values-CHART.yaml](./examples) files.

**Note:** these values are just sample values. The related charts need a fine-grained configuration to be suitable for production, see the available values for each one of them:

- [nuxeo](nuxeo/values.yaml)
- [mongodb](https://github.com/bitnami/charts/blob/master/bitnami/mongodb/values.yaml)
- [elasticsearch](https://github.com/elastic/helm-charts/blob/master/elasticsearch/values.yaml)
- [kafka](https://github.com/bitnami/charts/blob/master/bitnami/kafka/values.yaml)
