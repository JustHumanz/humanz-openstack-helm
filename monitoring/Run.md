```
helm install monitoring-stack prometheus-community/kube-prometheus-stack \
  --create-namespace \
  --namespace monitoring \
  -f kube-prometheus-stack/values.yaml
```

```
helm upgrade --install nvidia-gpu-exporter utkuozdemir/nvidia-gpu-exporter \
    --create-namespace \
    --namespace monitoring \
    -f nvidia-gpu-exporter/values.yaml
```