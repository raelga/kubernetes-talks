import json
import sqlite3
from http.server import BaseHTTPRequestHandler, HTTPServer

DB = "/data/notas.db"


def conectar():
    return sqlite3.connect(DB)


with conectar() as db:
    db.execute("CREATE TABLE IF NOT EXISTS notas (texto TEXT NOT NULL)")


class Backend(BaseHTTPRequestHandler):
    def responder(self, status, contenido):
        cuerpo = json.dumps(contenido).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(cuerpo)))
        self.end_headers()
        self.wfile.write(cuerpo)

    def do_GET(self):
        if self.path == "/health":
            self.responder(200, {"servicio": "backend", "estado": "ok"})
        elif self.path == "/notas":
            with conectar() as db:
                notas = [fila[0] for fila in db.execute("SELECT texto FROM notas ORDER BY rowid")]
            self.responder(200, {"notas": notas})
        else:
            self.responder(404, {"error": "ruta desconocida"})

    def do_POST(self):
        if self.path != "/notas":
            self.responder(404, {"error": "ruta desconocida"})
            return
        try:
            longitud = int(self.headers.get("Content-Length", "0"))
            if not 0 < longitud <= 4096:
                raise ValueError("longitud inválida")
            datos = json.loads(self.rfile.read(longitud))
            texto = datos["texto"]
            if not isinstance(texto, str) or not texto.strip():
                raise ValueError("texto vacío")
        except (ValueError, KeyError, TypeError):
            self.responder(400, {"error": "envía JSON con un texto no vacío"})
            return
        with conectar() as db:
            db.execute("INSERT INTO notas (texto) VALUES (?)", (texto,))
        self.responder(201, {"texto": texto})


HTTPServer(("0.0.0.0", 8000), Backend).serve_forever()
