import json
import os
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

BACKEND_URL = os.environ.get("BACKEND_URL", "http://backend:8000").rstrip("/")


class Frontend(BaseHTTPRequestHandler):
    def reenviar(self):
        if self.path not in ("/health", "/notas"):
            self.send_error(404)
            return
        cuerpo = None
        if self.command == "POST":
            try:
                longitud = int(self.headers.get("Content-Length", "0"))
            except ValueError:
                self.send_error(400)
                return
            if not 0 < longitud <= 4096:
                self.send_error(400)
                return
            cuerpo = self.rfile.read(longitud)
        peticion = Request(BACKEND_URL + self.path, data=cuerpo, method=self.command,
                           headers={"Content-Type": "application/json"})
        try:
            with urlopen(peticion, timeout=3) as respuesta:
                status, datos = respuesta.status, respuesta.read()
        except HTTPError as error:
            status, datos = error.code, error.read()
        except (URLError, TimeoutError) as error:
            print(f"Error de conexión con {BACKEND_URL}: {error}", flush=True)
            status = 502
            datos = json.dumps({"error": "backend no disponible"}).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(datos)))
        self.end_headers()
        self.wfile.write(datos)

    do_GET = reenviar
    do_POST = reenviar


HTTPServer(("0.0.0.0", 8080), Frontend).serve_forever()
