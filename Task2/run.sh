#!/usr/bin/env bash
# Полный прогон задания 2 на Minikube. Запускать из директории Task2.
set -euo pipefail

minikube start --driver=docker --cpus=2 --memory=4096
minikube addons enable metrics-server

kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f hpa.yaml

kubectl rollout status deployment/scaletestapp --timeout=180s
kubectl get deploy,svc,hpa

echo
echo "URL приложения: $(minikube service scaletestapp --url)"
echo "Дальше: locust -f locustfile.py --host=\$(minikube service scaletestapp --url)"
echo "Веб-интерфейс Locust: http://localhost:8089 - 200 пользователей, hatch rate 20"
echo "Наблюдение: kubectl get hpa scaletestapp -w   |   minikube dashboard"
