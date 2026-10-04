"""Correções de dados após a revisão dos ciclos com a planilha (04/10/2026).

1. Remove as 2 entradas "Recebido bazar" importadas como oferta de culto
   (duplicavam as linhas "Repasse bazar" que já estão em ofertas alçadas).
2. Lança a oferta "culto de doutrina" digitada com data 08/09/2029 no ciclo
   aberto (14/09/2026), pois o ciclo 10/08–13/09 já foi prestado sem ela.
3. Cadastra os tipos de receita e vincula cada entrada ao seu tipo.
4. Reabre o ciclo 14/09/2026–11/10/2026, que ainda está em andamento.

Uso: python scripts/fix-cycles-2026-10.py [--apply]
Sem --apply apenas mostra o que seria feito. Antes de aplicar, salva um
backup JSON das linhas afetadas na pasta indicada por --backup-dir.
"""

from __future__ import annotations

import argparse
import json
import os
import uuid
from datetime import datetime
from pathlib import Path
from urllib.request import Request, urlopen

CONGREGATION_ID = "f4f1212d-b728-4a42-8fee-fec6abab33f1"
OPEN_CLOSURE_START = "2026-09-14"
OPEN_CLOSURE_END = "2026-10-11"
WRONG_DATE_ENTRY_ID = "dd1d30c9-f111-5d93-bf1b-18556e69740b"
DUPLICATED_BAZAR_IDS = [
    "b78062eb-5a67-590a-8705-be2f2b72ae35",
    "7f1086d0-b3cb-5778-8461-57e92bc85d82",
]
REVENUE_CATEGORIES = [
    ("DIZIMOS", "DIZIMO", "Dízimo"),
    ("OFERTAS_CULTO", "OFERTA_CULTO", "Oferta de culto"),
    ("OFERTAS_ALCADAS", "OFERTA_ALCADA", "Oferta alçada"),
    ("OFERTAS_ALCADAS", "BAZAR", "Bazar"),
]


def load_env() -> None:
    env_file = Path(__file__).resolve().parent.parent / ".env"
    for line in env_file.read_text(encoding="utf-8").splitlines():
        if "=" in line and not line.startswith("#"):
            key, value = line.split("=", 1)
            os.environ.setdefault(key.strip(), value.strip())


class Rest:
    def __init__(self, url: str, key: str, apply: bool) -> None:
        self.base = url.rstrip("/") + "/rest/v1"
        self.key = key
        self.apply = apply

    def call(self, method: str, path: str, body: object | None = None, prefer: str = "") -> object:
        if method != "GET" and not self.apply:
            print(f"  [prévia] {method} {path} {json.dumps(body, ensure_ascii=False) if body else ''}")
            return []
        request = Request(
            f"{self.base}/{path}",
            data=json.dumps(body).encode() if body is not None else None,
            method=method,
            headers={
                "apikey": self.key,
                "Authorization": f"Bearer {self.key}",
                "Content-Type": "application/json",
                "Prefer": prefer or "return=representation",
            },
        )
        with urlopen(request, timeout=30) as response:
            content = response.read()
            return json.loads(content) if content else []


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true")
    parser.add_argument("--backup-dir", default=".")
    args = parser.parse_args()
    load_env()
    rest = Rest(os.environ["SUPABASE_URL"], os.environ["SUPABASE_SERVICE_ROLE_KEY"], args.apply)
    c = CONGREGATION_ID

    closure = rest.call(
        "GET",
        f"accountability_closures?select=*&congregation_id=eq.{c}"
        f"&period_start=eq.{OPEN_CLOSURE_START}&period_end=eq.{OPEN_CLOSURE_END}",
    )[0]
    affected_entry_ids = ",".join([WRONG_DATE_ENTRY_ID, *DUPLICATED_BAZAR_IDS])
    backup = {
        "entries": rest.call("GET", f"financial_entries?select=*&id=in.({affected_entry_ids})"),
        "entry_lines": rest.call(
            "GET", f"financial_entry_lines?select=*&financial_entry_id=in.({','.join(DUPLICATED_BAZAR_IDS)})"
        ),
        "closure": closure,
        "closure_balances": rest.call("GET", f"accountability_closure_balances?select=*&closure_id=eq.{closure['id']}"),
        "closure_allocations": rest.call(
            "GET", f"accountability_closure_allocations?select=*&closure_id=eq.{closure['id']}"
        ),
    }
    backup_file = Path(args.backup_dir) / f"backup-fix-cycles-{datetime.now():%Y%m%d-%H%M%S}.json"
    backup_file.write_text(json.dumps(backup, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Backup salvo em {backup_file}")

    print("1. Removendo entradas de bazar duplicadas")
    ids = ",".join(DUPLICATED_BAZAR_IDS)
    rest.call("DELETE", f"financial_entry_lines?financial_entry_id=in.({ids})")
    rest.call("DELETE", f"financial_entries?id=in.({ids})")

    print("2. Corrigindo a oferta com data 08/09/2029")
    rest.call("PATCH", f"financial_entries?id=eq.{WRONG_DATE_ENTRY_ID}", {
        "entry_date": OPEN_CLOSURE_START,
        "description": "culto de doutrina (oferta de 08/09/2026 lançada com data errada na planilha)",
    })

    print("3. Cadastrando tipos de receita")
    types = {
        row["code"]: row["id"]
        for row in rest.call("GET", f"entry_types?select=id,code&congregation_id=eq.{c}")
    }
    categories: dict[str, str] = {}
    for fund, code, name in REVENUE_CATEGORIES:
        category_id = str(uuid.uuid5(uuid.NAMESPACE_URL, f"revenue-category|{c}|{fund}|{code}"))
        categories[code] = category_id
        rest.call(
            "POST",
            "revenue_categories?on_conflict=congregation_id,entry_type_id,code",
            {"id": category_id, "congregation_id": c, "entry_type_id": types[fund], "code": code, "name": name},
            "resolution=merge-duplicates,return=minimal",
        )
    rest.call("PATCH", f"financial_entries?congregation_id=eq.{c}&entry_type_id=eq.{types['DIZIMOS']}",
              {"revenue_category_id": categories["DIZIMO"]})
    rest.call("PATCH", f"financial_entries?congregation_id=eq.{c}&entry_type_id=eq.{types['OFERTAS_CULTO']}",
              {"revenue_category_id": categories["OFERTA_CULTO"]})
    rest.call("PATCH", f"financial_entries?congregation_id=eq.{c}&entry_type_id=eq.{types['OFERTAS_ALCADAS']}",
              {"revenue_category_id": categories["OFERTA_ALCADA"]})
    rest.call("PATCH", f"financial_entries?congregation_id=eq.{c}&entry_type_id=eq.{types['OFERTAS_ALCADAS']}"
                       "&description=ilike.*bazar*",
              {"revenue_category_id": categories["BAZAR"]})

    print("4. Reabrindo o ciclo 14/09/2026–11/10/2026")
    rest.call("DELETE", f"accountability_closure_allocations?closure_id=eq.{closure['id']}")
    rest.call("DELETE", f"accountability_closure_balances?closure_id=eq.{closure['id']}")
    rest.call("PATCH", f"accountability_closures?id=eq.{closure['id']}", {
        "status": "OPEN",
        "closed_at": None,
        "notes": "Ciclo atual. A data final é uma previsão até o fechamento.",
    })
    print("Concluído." if args.apply else "Prévia concluída. Use --apply para gravar.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
