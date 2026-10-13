# Задание 2. Динамическое масштабирование контейнеров

Тестовое приложение: `ghcr.io/yandex-practicum/scaletestapp:latest` (порт 8080, `GET /` - id пода, `GET /metrics` - метрики Prometheus).

## Файлы

- `deployment.yaml` - Deployment, 1 реплика, `limits.memory: 30Mi`, `requests.memory: 20Mi` (HPA считает утилизацию относительно requests), readiness/liveness probes.
- `service.yaml` - Service типа NodePort (порт 30080) для доступа из Locust.
- `hpa.yaml` - HorizontalPodAutoscaler `autoscaling/v2` по средней утилизации памяти 80 %, 1..10 реплик; scale-up без окна стабилизации, scale-down с окном 60 с.
- `locustfile.py` - сценарий нагрузки.
- `run.sh` - поднятие Minikube с metrics-server и применение манифестов.
- `evidence/` - подтверждение масштабирования: `hpa-watch.log` (`kubectl get hpa -w`), `pods.log`, скриншоты дашборда Minikube и Locust.

## Как воспроизвести

```bash
./run.sh                                             # minikube + metrics-server + манифесты
kubectl get hpa scaletestapp -w                      # в отдельном терминале
locust -f locustfile.py --host=$(minikube service scaletestapp --url)
# http://localhost:8089 -> Users 200, Spawn rate 20 -> Start
minikube dashboard                                   # Workloads -> Deployments -> scaletestapp
```
