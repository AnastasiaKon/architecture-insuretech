"""Минимальный аналог ghcr.io/yandex-practicum/scaletestapp для arm64.
GET /        -> имя пода (hostname)
GET /metrics -> http_requests_total в формате Prometheus
Каждый запрос дополнительно удерживает немного памяти, чтобы HPA по памяти было что измерять.
"""
import os
import socket
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

counter = 0
lock = threading.Lock()
ballast = []  # растёт под нагрузкой, имитирует рост памяти приложения


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):  # тише в логах
        pass

    def do_GET(self):
        global counter
        if self.path == "/metrics":
            body = ("# HELP http_requests_total Total HTTP requests\n"
                    "# TYPE http_requests_total counter\n"
                    f"http_requests_total {counter}\n").encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; version=0.0.4")
        else:
            with lock:
                counter += 1
                if len(ballast) < 400:
                    ballast.append(bytearray(64 * 1024))  # +64 КБ за запрос, до ~25 МБ
            body = (socket.gethostname() + "\n").encode()
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", int(os.getenv("PORT", "8080"))), H).serve_forever()
