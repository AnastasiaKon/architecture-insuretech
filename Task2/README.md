# Задание 2. Динамическое масштабирование контейнеров

## Файлы

| Файл | Назначение |
|---|---|
| `deployment.yaml` | Deployment: 1 реплика, `limits.memory: 30Mi`, `requests.memory: 15Mi` (HPA считает утилизацию относительно requests), readiness/liveness probes |
| `service.yaml` | Service типа NodePort (30080) для доступа к приложению |
| `hpa.yaml` | HorizontalPodAutoscaler `autoscaling/v2`: средняя утилизация памяти 80 %, 1..10 реплик, scale-up без окна стабилизации, scale-down с окном 60 с |
| `locustfile.py` | Сценарий нагрузки из условия задания |
| `scaletestapp-arm64/` | Образ тестового приложения для Apple Silicon (см. ниже) |
| `mac_setup_and_run.sh` | Установка инструментов, Minikube + metrics-server, сборка образа, манифесты, нагрузка, сбор логов |
| `rerun_test.sh` | Повторный прогон только теста на уже поднятом кластере |
| `evidence/` | Логи и скриншоты, подтверждающие масштабирование |

## Образ приложения

`ghcr.io/yandex-practicum/scaletestapp:latest` опубликован только для `linux/amd64`; в Minikube на Apple Silicon (arm64) под не стартует: `failed to pull image: no match for platform in manifest`. Запуск через x86-эмуляцию (Colima + QEMU) не дал рабочего кластера. Поэтому использован функциональный аналог `scaletestapp-arm64/` с тем же контрактом - `GET /` возвращает имя пода, `GET /metrics` отдаёт `http_requests_total` в формате Prometheus; образ собирается прямо в Docker Minikube (`image: scaletestapp:local`, `imagePullPolicy: Never`).

## Окружение

macOS (Apple Silicon), Colima 4 CPU / 6 ГБ как Docker runtime, Minikube v1.37 (driver docker, 2 CPU / 4 ГБ), Kubernetes v1.37, metrics-server v0.9, Locust. Доступ к приложению из Locust - через `kubectl port-forward svc/scaletestapp 8080:8080` (на macOS NodePort Minikube снаружи напрямую недоступен).

## Результат

Нагрузка Locust: 300 пользователей, spawn rate 30, 5 минут. HPA поднял деплоймент с 1 до 10 реплик (максимум):

```
NAME           REFERENCE                 TARGETS           MINPODS   MAXPODS   REPLICAS   AGE
scaletestapp   Deployment/scaletestapp   memory: 81%/80%   1         10        1          55s
scaletestapp   Deployment/scaletestapp   memory: 96%/80%   1         10        2          4m3s
scaletestapp   Deployment/scaletestapp   memory: 92%/80%   1         10        3          5m2s
scaletestapp   Deployment/scaletestapp   memory: 95%/80%   1         10        4          6m2s
scaletestapp   Deployment/scaletestapp   memory: 98%/80%   1         10        5          7m1s
...
scaletestapp   Deployment/scaletestapp   memory: 134%/80%  1         10        10         13m
```

События HPA (`08_scale_events.log`): `SuccessfulRescale New size: 2 ... 5; reason: memory resource utilization (percentage of request) above target`.

Подтверждения в `evidence/`:

- `03_hpa_watch.log` - `kubectl get hpa -w`: рост REPLICAS с 1 до 10 с ростом утилизации памяти;
- `04_pods_watch.log` - список подов каждые 15 с: появление новых реплик;
- `08_scale_events.log`, `07_hpa_describe.log` - события и описание HPA;
- `10_dashboard_deployment.png` - дашборд Minikube, Deployment scaletestapp: Pods status 10 / 10 / 10;
- `11_dashboard_pods.png` - дашборд Minikube, список подов с потреблением памяти;
- `05_locust_report.html`, `05_locust_tail.log`, `locust_*.csv` - отчёт Locust;
- `01_initial_state.log`, `06_final_state.log`, `09_top_pods.log` - состояние до и после.

Наблюдение: один под с лимитом 30Mi под такой нагрузкой перезапускался по OOM, и ~90 % запросов Locust завершались `connection reset` - ровно симптом из условия («нестабильное поведение и постоянные перезагрузки подов из-за нехватки памяти»). После масштабирования до 10 реплик поды стабильны (`Restarts: 0` на скриншоте).

## Воспроизведение

```bash
bash mac_setup_and_run.sh      # всё с нуля
bash rerun_test.sh             # только тест на поднятом кластере
```
