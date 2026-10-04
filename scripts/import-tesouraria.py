"""Importa o histórico financeiro da planilha para o Supabase via REST.

Por segurança, o modo padrão é --dry-run. A gravação exige:
  --organization-id, --congregation-id, --created-by e --service-role-key

O script não importa credenciais da aba de usuários da planilha.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import uuid
from datetime import date, datetime
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Any
from urllib.error import HTTPError
from urllib.request import Request, urlopen

from openpyxl import load_workbook


def clean(value: Any) -> str:
    if value is None:
        return ""
    text = re.sub(r"\s+", " ", str(value).strip())
    replacements = {
        "�": "Á",
        "Ã�": "Á",
        "Ã‰": "É",
        "ÃŠ": "Ê",
        "Ã“": "Ó",
        "Ãš": "Ú",
        "Ã‡": "Ç",
        "Ãƒ": "Ã",
    }
    for source, target in replacements.items():
        text = text.replace(source, target)
    return text


def money(value: Any) -> Decimal:
    if value is None or value == "":
        return Decimal("0")
    if isinstance(value, (int, float, Decimal)):
        return Decimal(str(value)).quantize(Decimal("0.0001"))
    normalized = clean(value).replace(".", "").replace(",", ".")
    try:
        return Decimal(normalized).quantize(Decimal("0.0001"))
    except InvalidOperation as exc:
        raise ValueError(f"valor monetário inválido: {value!r}") from exc


def iso_date(value: Any) -> str | None:
    if isinstance(value, datetime):
        return value.date().isoformat()
    if isinstance(value, date):
        return value.isoformat()
    text = clean(value)
    if not text:
        return None
    for fmt in ("%d/%m/%Y", "%d/%m/%y", "%Y-%m-%d"):
        try:
            return datetime.strptime(text, fmt).date().isoformat()
        except ValueError:
            pass
    return None


def slug(value: str) -> str:
    result = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    return result or "sem-categoria"


def stable_id(prefix: str, *parts: Any) -> str:
    digest = hashlib.sha256("|".join(clean(part) for part in parts).encode()).hexdigest()[:24]
    return f"{prefix}-{digest}"


def stable_uuid(*parts: Any) -> str:
    return str(uuid.uuid5(uuid.NAMESPACE_URL, "|".join(clean(part) for part in parts)))


def rows(sheet: Any) -> list[dict[str, Any]]:
    values = list(sheet.values)
    if not values:
        return []
    headers = [clean(value).lower() for value in values[0]]
    result = []
    for raw in values[1:]:
        item = {headers[i]: raw[i] if i < len(raw) else None for i in range(len(headers))}
        if any(value not in (None, "") for value in raw):
            result.append(item)
    return result


def find_column(item: dict[str, Any], *names: str) -> Any:
    for name in names:
        for key, value in item.items():
            if name in key:
                return value
    return None


def category_names(workbook: Any) -> list[str]:
    result: set[str] = set()
    sheet = workbook["TIPOS_DESPESAS"]
    for row in sheet.iter_rows(values_only=True):
        value = clean(row[0] if row else "")
        if value:
            result.add(value.upper())
    for item in rows(workbook["DESPESAS"]):
        value = clean(find_column(item, "categoria"))
        if value:
            result.add(value.upper())
    return sorted(result)


def build_preview(workbook: Any) -> dict[str, Any]:
    offers = rows(workbook["OFERTAS"])
    tithes = rows(workbook["DÍZIMOS"])
    raised = rows(workbook["ALCADAS"])
    bazaar = rows(workbook["BAZAR"])
    expenses = rows(workbook["DESPESAS"])
    entries = []
    for source, source_rows in (
        ("OFERTAS", offers),
        ("DÍZIMOS", tithes),
        ("ALCADAS", raised),
        ("BAZAR", bazaar),
    ):
        for item in source_rows:
            entry_date = iso_date(find_column(item, "data"))
            amount = money(find_column(item, "total de ofertas", "valor", "valor recebido pix"))
            if amount <= 0 and source == "OFERTAS":
                amount = money(find_column(item, "total"))
            if entry_date and amount > 0:
                pix = money(find_column(item, "valor recebido pix", "vlr. recebido pix"))
                cash = money(find_column(item, "vlr. recebido salva", "valor recebido salva"))
                if source != "OFERTAS":
                    pix = money(find_column(item, "valor pix")) if "pix" in clean(
                        find_column(item, "método", "metodo")
                    ).lower() else Decimal("0")
                    cash = amount if pix <= 0 else amount - pix
                if pix <= 0 and cash <= 0:
                    cash = amount
                if pix + cash != amount:
                    cash = amount - pix
                entries.append({
                    "source": source,
                    "date": entry_date,
                    "amount": str(amount),
                    "description": clean(find_column(item, "descrição", "nome")),
                    "category": clean(find_column(item, "categoria")) or source,
                    "payment_lines": {"PIX": str(pix), "CASH": str(cash)} if pix > 0 and cash > 0 else {
                        "PIX": str(pix) if pix > 0 else str(cash),
                    } if pix > 0 else {"CASH": str(cash)},
                    "entry_type_code": {
                        "DÍZIMOS": "DIZIMOS",
                        "ALCADAS": "OFERTAS_ALCADAS",
                    }.get(source, "OFERTAS_CULTO"),
                    "import_key": stable_id("entry", source, entry_date, amount, clean(item)),
                })
    payable_rows = []
    for item in expenses:
        amount = money(find_column(item, "valor a pagar"))
        if amount <= 0:
            continue
        payable_rows.append({
            "description": clean(find_column(item, "descrição")),
            "amount": str(amount),
            "category": clean(find_column(item, "categoria")) or "OUTROS",
            "due_date": iso_date(find_column(item, "data de vencimento")),
            "payment_date": iso_date(find_column(item, "data pagamento")),
            "paid_sources": {
                "OFERTAS_CULTO": str(money(find_column(item, "vlr. pago (ofertas)", "pago ofertas"))),
                "DIZIMOS": str(money(find_column(item, "vlr. pago (dizimos)", "pago dizimos"))),
                "OFERTAS_ALCADAS": str(money(find_column(item, "vlr. pago (alçadas)", "pago alçadas"))),
            },
            "import_key": stable_id("payable", clean(item)),
        })
    return {
        "categories": category_names(workbook),
        "entries": entries,
        "payables": payable_rows,
        "ignored": {
            "offers_without_date_or_value": sum(
                1 for item in offers
                if not iso_date(find_column(item, "data"))
                or money(find_column(item, "total de ofertas", "valor", "total")) <= 0
            ),
            "expenses_without_positive_amount": sum(
                1 for item in expenses if money(find_column(item, "valor a pagar")) <= 0
            ),
        },
    }


def build_members_preview(workbook: Any) -> list[dict[str, Any]]:
    sheet_name = workbook.sheetnames[0]
    result = []
    for item in rows(workbook[sheet_name]):
        name = clean(find_column(item, "nome"))
        if not name:
            continue
        baptized = clean(find_column(item, "batizado do espirito", "batizado do espírito")).upper()
        result.append({
            "full_name": name,
            "birth_date": iso_date(find_column(item, "data de nascimento")),
            "rg": clean(find_column(item, "rg")) or None,
            "marital_status": clean(find_column(item, "estado civil")) or None,
            "cpf": clean(find_column(item, "cpf")) or None,
            "mother_name": clean(find_column(item, "filiação mãe", "filiacao mae")) or None,
            "father_name": clean(find_column(item, "filiação pai", "filiacao pai")) or None,
            "spouse_name": clean(find_column(item, "conjuge", "cônjuge")) or None,
            "address": clean(find_column(item, "endereço", "endereco")) or None,
            "nationality": clean(find_column(item, "nacionalidade")) or None,
            "birthplace": clean(find_column(item, "naturalidade")) or None,
            "ministry_role": clean(find_column(item, "função ministerial", "funcao ministerial")) or None,
            "ministry_role_since": iso_date(find_column(item, "função desde", "funcao desde")),
            "holy_spirit_baptism": True if baptized == "SIM" else False if baptized == "NÃO" or baptized == "NAO" else None,
            "holy_spirit_baptism_date": iso_date(find_column(item, "data batismo no espirito", "data batismo no espírito")),
            "education": clean(find_column(item, "escolaridade")) or None,
            "children_count": int(money(find_column(item, "n filhos", "nº filhos"))) if find_column(item, "n filhos", "nº filhos") not in (None, "") else None,
            "phone": clean(find_column(item, "telefone")) or None,
            "email": clean(find_column(item, "email")) or None,
            "import_key": stable_id("member", name, clean(find_column(item, "cpf", "email"))),
        })
    return result


def request_json(url: str, key: str, method: str, payload: Any) -> Any:
    body = json.dumps(payload).encode()
    request = Request(
        url,
        data=body,
        method=method,
        headers={
            "apikey": key,
            "Authorization": f"Bearer {key}",
            "Content-Type": "application/json",
            "Prefer": "resolution=merge-duplicates,return=representation",
        },
    )
    try:
        with urlopen(request, timeout=30) as response:
            content = response.read()
            return json.loads(content) if content else []
    except HTTPError as exc:
        detail = exc.read().decode(errors="replace")
        raise RuntimeError(f"Supabase respondeu HTTP {exc.code}: {detail}") from exc


def rest_get(base: str, key: str, table: str, query: str) -> list[dict[str, Any]]:
    request = Request(
        f"{base}/{table}?{query}",
        headers={"apikey": key, "Authorization": f"Bearer {key}"},
    )
    with urlopen(request, timeout=30) as response:
        return json.loads(response.read() or b"[]")


def import_financial_data(preview: dict[str, Any], args: argparse.Namespace, base: str) -> None:
    cycle_id = stable_uuid("cycle", args.congregation_id, "historico-planilha")
    cycles = rest_get(
        base,
        args.service_role_key,
        "accountability_cycles",
        f"select=id,name&congregation_id=eq.{args.congregation_id}",
    )
    cycles = [cycle for cycle in cycles if cycle.get("name") == "Histórico importado"]
    if not cycles:
        request_json(base + "/accountability_cycles", args.service_role_key, "POST", {
            "id": cycle_id,
            "congregation_id": args.congregation_id,
            "name": "Histórico importado",
            "start_date": min((row["date"] for row in preview["entries"]), default="2020-01-01"),
            "end_date": max((row["date"] for row in preview["entries"]), default="2099-12-31"),
            "opening_balance": 0,
            "status": "OPEN",
        })
    else:
        cycle_id = cycles[0]["id"]

    type_ids: dict[str, str] = {}
    type_names = {
        "DIZIMOS": "Dízimos",
        "OFERTAS_CULTO": "Ofertas de culto",
        "OFERTAS_ALCADAS": "Ofertas alçadas",
    }
    for code, name in type_names.items():
        type_id = stable_uuid("entry-type", args.congregation_id, code)
        type_ids[code] = type_id
        request_json(base + "/entry_types?on_conflict=congregation_id,code", args.service_role_key, "POST", {
            "id": type_id,
            "congregation_id": args.congregation_id,
            "code": code,
            "name": name,
            "active": True,
        })

    category_ids: dict[str, str] = {}
    for name in preview["categories"]:
        category_id = stable_uuid("expense-category", args.congregation_id, name)
        category_ids[name] = category_id
        request_json(base + "/expense_categories?on_conflict=congregation_id,name", args.service_role_key, "POST", {
            "id": category_id,
            "congregation_id": args.congregation_id,
            "name": name,
            "active": True,
        })

    for row in preview["entries"]:
        entry_id = stable_uuid("financial-entry", args.congregation_id, row["import_key"])
        request_json(base + "/financial_entries", args.service_role_key, "POST", {
            "id": entry_id,
            "congregation_id": args.congregation_id,
            "cycle_id": cycle_id,
            "entry_type_id": type_ids[row["entry_type_code"]],
            "entry_date": row["date"],
            "description": row["description"] or row["source"],
            "total_amount": row["amount"],
            "status": "CONFIRMED",
            "created_by": args.created_by,
        })
        for method, amount in row["payment_lines"].items():
            if Decimal(amount) > 0:
                request_json(base + "/financial_entry_lines", args.service_role_key, "POST", {
                    "id": stable_uuid("entry-line", entry_id, method),
                    "financial_entry_id": entry_id,
                    "payment_method": method,
                    "amount": amount,
                })

    for row in preview["payables"]:
        category_name = row["category"].upper()
        category_id = category_ids.get(category_name)
        if not category_id:
            category_id = stable_uuid("expense-category", args.congregation_id, category_name)
            request_json(base + "/expense_categories?on_conflict=congregation_id,name", args.service_role_key, "POST", {
                "id": category_id,
                "congregation_id": args.congregation_id,
                "name": category_name,
                "active": True,
            })
        payable_id = stable_uuid("payable", args.congregation_id, row["import_key"])
        due_date = row["due_date"] or row.get("issue_date") or date.today().isoformat()
        amount = Decimal(row["amount"])
        request_json(base + "/payables", args.service_role_key, "POST", {
            "id": payable_id,
            "congregation_id": args.congregation_id,
            "cycle_id": cycle_id,
            "category_id": category_id,
            "description": row["description"] or "Despesa importada",
            "issue_date": due_date,
            "due_date": due_date,
            "amount": str(amount),
            "status": "OPEN",
            "notification_days_before": 3,
        })
        paid_sources = {
            key: value for key, value in row["paid_sources"].items() if Decimal(value) > 0
        }
        paid_total = sum((Decimal(value) for value in paid_sources.values()), Decimal("0"))
        for source, source_amount in paid_sources.items():
            request_json(base + "/payable_funding_allocations", args.service_role_key, "POST", {
                "id": stable_uuid("payable-allocation", payable_id, source),
                "payable_id": payable_id,
                "congregation_id": args.congregation_id,
                "revenue_type_code": source,
                "amount": source_amount,
            })
        if paid_total > 0:
            payment_id = stable_uuid("payable-payment", payable_id)
            request_json(base + "/payable_payments", args.service_role_key, "POST", {
                "id": payment_id,
                "payable_id": payable_id,
                "congregation_id": args.congregation_id,
                "payment_date": row["payment_date"] or due_date,
                "amount": str(paid_total),
                "payment_method": "CASH",
            })
            if paid_total >= amount:
                request_json(
                    f"{base}/payables?id=eq.{payable_id}",
                    args.service_role_key,
                    "PATCH",
                    {"status": "PAID"},
                )
    print(f"Histórico importado: {len(preview['entries'])} receitas e {len(preview['payables'])} contas.")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--file", default="TESOURARIA - ADTCSGA EIXO DO CARRO.xlsx")
    parser.add_argument("--members-file", default="membros.xlsx")
    parser.add_argument("--supabase-url", default=os.getenv("SUPABASE_URL"))
    parser.add_argument("--service-role-key", default=os.getenv("SUPABASE_SERVICE_ROLE_KEY"))
    parser.add_argument("--organization-id", default=os.getenv("IMPORT_ORGANIZATION_ID"))
    parser.add_argument("--congregation-id", default=os.getenv("IMPORT_CONGREGATION_ID"))
    parser.add_argument("--created-by", default=os.getenv("IMPORT_CREATED_BY"))
    parser.add_argument("--dry-run", action="store_true", default=False)
    parser.add_argument("--preview-file", default="import-preview.json")
    args = parser.parse_args()

    workbook = load_workbook(Path(args.file), read_only=True, data_only=True)
    preview = build_preview(workbook)
    members_path = Path(args.members_file)
    members = []
    if members_path.exists():
        members = build_members_preview(load_workbook(members_path, read_only=True, data_only=True))
    preview["members"] = members
    Path(args.preview_file).write_text(json.dumps(preview, ensure_ascii=False, indent=2), encoding="utf-8")
    print(
        f"Prévia: {len(preview['entries'])} receitas, "
        f"{len(preview['payables'])} despesas, "
        f"{len(preview['categories'])} categorias."
    )
    print(f"Membros encontrados: {len(members)}.")
    print(f"Linhas separadas: {json.dumps(preview['ignored'], ensure_ascii=False)}")

    if args.dry_run:
        print(f"Modo prévia: nenhum dado gravado. Detalhes em {args.preview_file}.")
        return 0

    required = {
        "SUPABASE_URL": args.supabase_url,
        "SUPABASE_SERVICE_ROLE_KEY": args.service_role_key,
        "IMPORT_ORGANIZATION_ID": args.organization_id,
        "IMPORT_CONGREGATION_ID": args.congregation_id,
        "IMPORT_CREATED_BY": args.created_by,
    }
    missing = [name for name, value in required.items() if not value]
    if missing:
        raise SystemExit(
            "Gravação bloqueada. Informe: " + ", ".join(missing) + ". "
            "Use --dry-run para somente gerar a prévia."
        )

    base = args.supabase_url.rstrip("/") + "/rest/v1"
    categories = [
        {
            "congregation_id": args.congregation_id,
            "name": name,
            "active": True,
        }
        for name in preview["categories"]
    ]
    if categories:
        request_json(f"{base}/expense_categories?on_conflict=congregation_id,name", args.service_role_key, "POST", categories)
    if preview.get("members"):
        request_json(f"{base}/congregation_members?on_conflict=congregation_id,import_key", args.service_role_key, "POST", [
            {**member, "congregation_id": args.congregation_id}
            for member in preview["members"]
        ])
        print(f"{len(preview['members'])} membros importados.")
    import_financial_data(preview, args, base)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERRO: {exc}", file=sys.stderr)
        raise SystemExit(1)
