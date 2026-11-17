import argparse
import json
import sys
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

BASE = "http://localhost:8080"


def solicitar(ruta, datos=None):
    cuerpo = json.dumps(datos).encode("utf-8") if datos is not None else None
    peticion = Request(BASE + ruta, data=cuerpo, headers={"Content-Type": "application/json"})
    with urlopen(peticion, timeout=5) as respuesta:
        return respuesta.status, json.load(respuesta)


def main():
    parser = argparse.ArgumentParser(description="Valida el frontend y el backend de notas")
    parser.add_argument("accion", choices=("crear", "comprobar"))
    parser.add_argument("texto", help="texto único de la nota")
    args = parser.parse_args()
    try:
        status, salud = solicitar("/health")
        if status != 200 or salud != {"servicio": "backend", "estado": "ok"}:
            raise ValueError(f"respuesta inesperada de salud: {salud}")
        if args.accion == "crear":
            status, creada = solicitar("/notas", {"texto": args.texto})
            if status != 201 or creada.get("texto") != args.texto:
                raise ValueError(f"no se creó la nota: {creada}")
        status, listado = solicitar("/notas")
        if status != 200 or args.texto not in listado.get("notas", []):
            raise ValueError(f"nota no encontrada: {listado}")
    except (HTTPError, URLError, TimeoutError, ValueError, OSError) as error:
        print(f"Validación fallida: {error}", file=sys.stderr)
        return 1
    print(f"Validación correcta: frontend, backend y nota {args.texto!r}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
