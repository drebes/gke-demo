
## Get cluster credentials

```shell
$ gcloud container clusters get-credentials cluster-blue --region europe-west6 --project drebes-lab-gke-iap-cip-816d
Fetching cluster endpoint and auth data.
kubeconfig entry generated for cluster-blue.
```

## Create all objects

```shell
$ kubectl apply -f all.yaml
deployment.apps/echo-deployment created
deployment.apps/hello-deployment created
backendconfig.cloud.google.com/cdn-backendconfig created
service/echo-service created
service/hello-service created
managedcertificate.networking.gke.io/blue-cert created
ingress.networking.k8s.io/blue-ingress created
```

## Get the edge security policy

````
$ gcloud compute security-policies list
NAME
edge-policy
```

## Update backend services

```shell
$ gcloud compute backend-services list
NAME                                               BACKENDS                                                                                PROTOCOL
k8s1-c0d2838d-default-echo-service-8080-21f40faa   europe-west6-b/networkEndpointGroups/k8s1-c0d2838d-default-echo-service-8080-21f40faa   HTTP
k8s1-c0d2838d-default-hello-service-8080-1a7564fa  europe-west6-b/networkEndpointGroups/k8s1-c0d2838d-default-hello-service-8080-1a7564fa  HTTP
$ gcloud compute backend-services update k8s1-c0d2838d-default-echo-service-8080-21f40faa --edge-security-policy=edge-policy --global
Updated [https://www.googleapis.com/compute/v1/projects/drebes-lab-gke-iap-cip-816d/global/backendServices/k8s1-c0d2838d-default-echo-service-8080-21f40faa].
$ gcloud compute backend-services update k8s1-c0d2838d-default-hello-service-8080-1a7564fa --edge-security-policy=edge-policy --global
Updated [https://www.googleapis.com/compute/v1/projects/drebes-lab-gke-iap-cip-816d/global/backendServices/k8s1-c0d2838d-default-hello-service-8080-1a7564fa].
```