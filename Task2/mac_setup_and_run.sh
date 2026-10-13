#!/usr/bin/env bash
# Полный прогон задания 2 на macOS (Apple Silicon): установка инструментов, Minikube,
# манифесты, нагрузка Locust, сбор логов и скриншотов в Task2/evidence/.
# Запуск:  bash ~/architecture-insuretech/Task2/mac_setup_and_run.sh
set -euo pipefail

REPO="$HOME/architecture-insuretech"
EV="$REPO/Task2/evidence"
mkdir -p "$EV"
log() { printf "\n\033[1;34m==> %s\033[0m\n" "$*"; }

# ---------- 1. Homebrew ----------
if ! command -v brew >/dev/null 2>&1; then
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    log "Устанавливаю Homebrew (попросит пароль администратора)"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
fi
grep -q 'brew shellenv' "$HOME/.zprofile" 2>/dev/null || echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"

# ---------- 2. Инструменты ----------
log "Ставлю docker CLI, colima, minikube, kubectl, python/locust"
brew install --quiet docker colima minikube kubectl python@3.12 2>&1 | grep -vi "already installed" || true
python3 -m pip install --quiet --user locust 2>/dev/null || /opt/homebrew/bin/python3.12 -m pip install --quiet --user locust
LOCUST="$(python3 -m site --user-base 2>/dev/null)/bin/locust"
[ -x "$LOCUST" ] || LOCUST="$(/opt/homebrew/bin/python3.12 -m site --user-base)/bin/locust"

# ---------- 3. Docker runtime (Colima) ----------
if ! docker info >/dev/null 2>&1; then
  log "Запускаю Colima (Docker runtime), 4 CPU / 6 ГБ"
  colima start --cpu 4 --memory 6 --arch aarch64
fi
docker info >/dev/null

# ---------- 4. Minikube ----------
log "Поднимаю Minikube"
minikube status >/dev/null 2>&1 || minikube start --driver=docker --cpus=2 --memory=4096
minikube addons enable metrics-server

# ---------- 5. Манифесты ----------
cd "$REPO/Task2"
log "Применяю Deployment, Service, HPA"
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f hpa.yaml
kubectl rollout status deployment/scaletestapp --timeout=300s
sleep 30   # metrics-server должен собрать первые метрики
kubectl get deploy,svc,hpa -o wide | tee "$EV/01_initial_state.log"
kubectl top pods 2>/dev/null | tee -a "$EV/01_initial_state.log" || true

# ---------- 6. Нагрузка ----------
URL="$(minikube service scaletestapp --url | head -1)"
log "URL приложения: $URL"
curl -s "$URL/" | tee "$EV/02_app_response.log"; echo

log "Наблюдение за HPA в фоне -> evidence/03_hpa_watch.log"
kubectl get hpa scaletestapp -w > "$EV/03_hpa_watch.log" 2>&1 &
HPA_PID=$!
( while true; do date "+%H:%M:%S"; kubectl get pods -l app=scaletestapp --no-headers; sleep 15; done ) > "$EV/04_pods_watch.log" 2>&1 &
PODS_PID=$!

log "Запускаю Locust: 300 пользователей, spawn rate 30, 4 минуты (headless)"
"$LOCUST" -f locustfile.py --host="$URL" --headless -u 300 -r 30 --run-time 4m \
  --csv="$EV/locust" --html="$EV/05_locust_report.html" 2>&1 | tail -20 | tee "$EV/05_locust_tail.log"

sleep 20
kill $HPA_PID $PODS_PID 2>/dev/null || true

# ---------- 7. Итог ----------
log "Состояние после нагрузки"
kubectl get hpa scaletestapp | tee "$EV/06_final_state.log"
kubectl get pods -l app=scaletestapp | tee -a "$EV/06_final_state.log"
kubectl describe hpa scaletestapp | tee "$EV/07_hpa_describe.log" >/dev/null
kubectl get events --sort-by=.lastTimestamp | grep -iE "scaled|hpa|horizontalpodautoscaler" | tee "$EV/08_scale_events.log" || true

log "Открываю дашборд Minikube - сделайте скриншот Deployments -> scaletestapp (⌘⇧4), сохраните в $EV"
minikube dashboard --url >/dev/null 2>&1 &
sleep 5
open "$(minikube dashboard --url 2>/dev/null | tail -1)#/deployment/default/scaletestapp?namespace=default" 2>/dev/null || true

echo
echo "Готово. Логи в $EV. Проверьте 03_hpa_watch.log - там видно рост REPLICAS."
