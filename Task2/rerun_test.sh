#!/usr/bin/env bash
# Повторный прогон только теста (кластер уже поднят): пересборка образа, манифесты, нагрузка, логи.
set -euo pipefail
REPO="$HOME/architecture-insuretech"; EV="$REPO/Task2/evidence"; mkdir -p "$EV"
LOCUST="$(python3 -m site --user-base 2>/dev/null)/bin/locust"; [ -x "$LOCUST" ] || LOCUST="$(/opt/homebrew/bin/python3.12 -m site --user-base)/bin/locust"
log() { printf "\n\033[1;34m==> %s\033[0m\n" "$*"; }
cd "$REPO/Task2"
log "Пересобираю образ"; eval "$(minikube docker-env)"; docker build -q -t scaletestapp:local scaletestapp-arm64; eval "$(minikube docker-env -u)"
log "Применяю манифесты"; kubectl delete hpa scaletestapp --ignore-not-found; kubectl apply -f deployment.yaml -f service.yaml -f hpa.yaml
kubectl rollout restart deployment/scaletestapp; kubectl rollout status deployment/scaletestapp --timeout=180s; sleep 45
kubectl get deploy,svc,hpa -o wide | tee "$EV/01_initial_state.log"; kubectl top pods | tee -a "$EV/01_initial_state.log" || true
pkill -f "port-forward svc/scaletestapp" 2>/dev/null || true
kubectl port-forward svc/scaletestapp 8080:8080 >/dev/null 2>&1 & PF=$!; sleep 3
URL="http://127.0.0.1:8080"; curl -s "$URL/" | tee "$EV/02_app_response.log"; echo
kubectl get hpa scaletestapp -w > "$EV/03_hpa_watch.log" 2>&1 & H=$!
( while true; do date "+%H:%M:%S"; kubectl get pods -l app=scaletestapp --no-headers; sleep 15; done ) > "$EV/04_pods_watch.log" 2>&1 & P=$!
log "Locust: 300 пользователей, 5 минут"
"$LOCUST" -f locustfile.py --host="$URL" --headless -u 300 -r 30 --run-time 5m --csv="$EV/locust" --html="$EV/05_locust_report.html" 2>&1 | tail -20 | tee "$EV/05_locust_tail.log"
sleep 20; kill $H $P $PF 2>/dev/null || true
log "Итог"; kubectl get hpa scaletestapp | tee "$EV/06_final_state.log"; kubectl get pods -l app=scaletestapp | tee -a "$EV/06_final_state.log"
kubectl describe hpa scaletestapp > "$EV/07_hpa_describe.log"
kubectl get events --sort-by=.lastTimestamp | grep -iE "scaled|horizontalpodautoscaler" | tee "$EV/08_scale_events.log" || true
log "Дашборд"; nohup minikube dashboard > "$EV/dashboard_url.log" 2>&1 & sleep 15
DASH="$(grep -o 'http://127.0.0.1:[0-9]*/api/v1/namespaces/kubernetes-dashboard/services/[^ ]*' "$EV/dashboard_url.log" | head -1)"
[ -n "$DASH" ] && open "${DASH}#/deployment/default/scaletestapp?namespace=default" || true
echo; echo "Готово: см. $EV/03_hpa_watch.log"
