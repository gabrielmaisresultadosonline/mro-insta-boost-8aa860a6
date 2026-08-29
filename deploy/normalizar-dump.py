#!/usr/bin/env python3
"""Normaliza exports SQL do AdminCentral para a stack self-hosted atual.

O arquivo original nunca é alterado. A saída normalizada é gravada em /tmp
e pode ser reaplicada com segurança pelo reparar.sh.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


def split_sql_values(value_list: str) -> list[str]:
    values: list[str] = []
    start = 0
    depth = 0
    quoted = False
    index = 0
    while index < len(value_list):
        char = value_list[index]
        if char == "'":
            if quoted and index + 1 < len(value_list) and value_list[index + 1] == "'":
                index += 2
                continue
            quoted = not quoted
        elif not quoted:
            if char in "([":
                depth += 1
            elif char in ")]":
                depth -= 1
            elif char == "," and depth == 0:
                values.append(value_list[start:index].strip())
                start = index + 1
        index += 1
    values.append(value_list[start:].strip())
    return values


def remove_generated_confirmed_at(line: str) -> str:
    prefix = "INSERT INTO auth.users ("
    if not line.startswith(prefix) or ") VALUES (" not in line:
        return line

    columns_end = line.index(") VALUES (")
    columns = [column.strip() for column in line[len(prefix):columns_end].split(",")]
    if "confirmed_at" not in columns:
        return line

    values_start = columns_end + len(") VALUES (")
    suffix_marker = ") ON CONFLICT"
    values_end = line.rfind(suffix_marker)
    if values_end < values_start:
        return line

    values = split_sql_values(line[values_start:values_end])
    if len(values) != len(columns):
        raise ValueError(
            f"auth.users possui {len(columns)} colunas e {len(values)} valores"
        )

    generated_index = columns.index("confirmed_at")
    del columns[generated_index]
    del values[generated_index]
    return (
        prefix
        + ", ".join(columns)
        + ") VALUES ("
        + ", ".join(values)
        + line[values_end:]
    )


def normalize(source: Path, destination: Path) -> None:
    text = source.read_text(encoding="utf-8")

    # information_schema.columns devolve ARRAY e USER-DEFINED como categorias,
    # não como nomes de tipos válidos para recriar as colunas.
    text = re.sub(r"\bUSER-DEFINED\b", "public.app_role", text)
    text = re.sub(r"\bARRAY\b", "text[]", text)

    # O exportador antigo omitiu o terminador dos corpos de funções.
    text = re.sub(r"(?m)^(\s*\$function\$)\s*$", r"\1;", text)

    # GoTrue atual define confirmed_at como GENERATED ALWAYS. O valor continua
    # preservado em email_confirmed_at/phone_confirmed_at e é recalculado.
    lines = [remove_generated_confirmed_at(line) for line in text.splitlines()]
    destination.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    if len(sys.argv) != 3:
        print("uso: normalizar-dump.py ORIGEM DESTINO", file=sys.stderr)
        return 2
    try:
        normalize(Path(sys.argv[1]), Path(sys.argv[2]))
    except (OSError, ValueError) as error:
        print(f"falha ao normalizar dump: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())