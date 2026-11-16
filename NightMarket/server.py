"""NightMarket 本機伺服器：頁面關閉後自動結束。
頁面每 5 秒送 /ping；關閉分頁時送 /bye（5 秒內沒有新 ping 就結束）；
完全沒有 ping（例如瀏覽器當掉）超過 150 秒也會結束。
"""
import http.server, os, sys, threading, time

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
os.chdir(os.path.dirname(os.path.abspath(__file__)))
deadline = time.time() + 60  # 啟動後 60 秒內要有頁面連上來
lock = threading.Lock()

def extend(sec):
    global deadline
    with lock:
        deadline = time.time() + sec

class H(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith("/ping"):
            extend(150); self.send_response(204); self.end_headers(); return
        super().do_GET()
    def do_POST(self):
        if self.path.startswith("/bye"):
            extend(5)
        self.send_response(204); self.end_headers()
    def log_message(self, *a):
        pass

srv = http.server.ThreadingHTTPServer(("127.0.0.1", PORT), H)

def watchdog():
    while True:
        time.sleep(1)
        with lock:
            late = time.time() > deadline
        if late:
            print("頁面已關閉，伺服器結束。")
            srv.shutdown()
            return

threading.Thread(target=watchdog, daemon=True).start()
srv.serve_forever()
