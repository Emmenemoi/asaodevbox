#!/bin/bash

openssl req -nodes -x509 -newkey rsa:4096 -keyout /etc/ssl/certs/asaodevbox_key.pem -out /etc/ssl/certs/asaodevbox_cert.pem -days 365 -subj "/C=FR/ST=IDF/L=Paris/O=ASAO/OU=DevOps/CN=asaodevbox.local" -addext "subjectAltName = IP:127.0.0.1, DNS:localhost, DNS:asaodevbox.local, DNS:asaodevbox, DNS:registry.asaodevbox.local, DNS:registry.asaodevbox"

microk8s.kubectl apply -f includes/ingress.yaml
microk8s.kubectl apply -f includes/dashboard.yaml
microk8s.kubectl apply -f includes/rbac.yaml

microk8s.kubectl patch deployment kubernetes-dashboard  --namespace kube-system --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/args", "value": [
  "--enable-insecure-login",
  "--insecure-bind-address=0.0.0.0"
]}]'
microk8s.kubectl patch deployment kubernetes-dashboard  --namespace kube-system --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/ports/0/containerPort", "value": 9090}]'
microk8s.kubectl patch deployment kubernetes-dashboard  --namespace kube-system --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/livenessProbe/httpGet/port", "value": 9090}]'
microk8s.kubectl patch deployment kubernetes-dashboard  --namespace kube-system --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/livenessProbe/httpGet/scheme", "value": HTTP}]'

microk8s.kubectl patch service kubernetes-dashboard  --namespace kube-system --type='json' -p='[{"op": "replace", "path": "/spec/ports", "value":[{"port":80,"protocol":"TCP","targetPort":9090}]}]'
