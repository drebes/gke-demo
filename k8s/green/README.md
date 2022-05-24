
## Get cluster credentials

```shell
$ gcloud container clusters get-credentials cluster-green --region europe-west6 --project drebes-lab-gke-iap-cip-816d
Fetching cluster endpoint and auth data.
kubeconfig entry generated for cluster-green.
```

## Create all objects

```shell
$ kubectl apply -f all.yaml
deployment.apps/echo-deployment created
deployment.apps/echo-deployment created
deployment.apps/hello-deployment created
service/echo-service created
service/hello-service created
```