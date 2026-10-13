Образ `ghcr.io/yandex-practicum/scaletestapp:latest` опубликован только для linux/amd64 и не запускается в Minikube на Apple Silicon (`no match for platform in manifest`). Здесь - его функциональный аналог для arm64 с тем же контрактом (`GET /` - id пода, `GET /metrics` - `http_requests_total`), который собирается прямо в Minikube:

```bash
eval $(minikube docker-env)
docker build -t scaletestapp:local Task2/scaletestapp-arm64
```

После сборки в `deployment.yaml` используется `image: scaletestapp:local`, `imagePullPolicy: Never`.
