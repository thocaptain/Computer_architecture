"""Per-instruction results from app05's ordered, fail-fast check protocol.

A PASS signature proves all checks completed. SELF_FAIL with case ID k proves
checks before k passed, k failed, and later checks were not run. Other outcomes
cannot prove per-case progress and are explicitly marked UNCONFIRMED.
"""
from collections import Counter
import csv
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "02_test" / "Milestone1" / "apps" / "app05_manifest.json"
COLUMNS = ["configuration", "core", "instruction", "status", "planned", "passed",
           "failed", "not_run", "unconfirmed"]
REPORT_COLUMNS = ["configuration", "core", "group", *COLUMNS[2:]]
INSTRUCTION_GROUPS = (
    ("Arithmetic", ("ADD", "ADDI", "SUB")),
    ("Comparison", ("SLT", "SLTI", "SLTU", "SLTIU")),
    ("Bitwise", ("XOR", "XORI", "OR", "ORI", "AND", "ANDI")),
    ("Shift", ("SLL", "SLLI", "SRL", "SRLI", "SRA", "SRAI")),
    ("Upper-immediate", ("LUI", "AUIPC")),
    ("Load", ("LB", "LBU", "LH", "LHU", "LW")),
    ("Store", ("SB", "SH", "SW")),
    ("Branch", ("BEQ", "BNE", "BLT", "BGE", "BLTU", "BGEU")),
    ("Jump", ("JAL", "JALR")),
)


def grouped_rows(rows):
    order = {name: (group_index, instruction_index, group)
             for group_index, (group, names) in enumerate(INSTRUCTION_GROUPS)
             for instruction_index, name in enumerate(names)}
    configurations = {"baseline": 0, "async": 1, "sync": 2}

    def key(row):
        group_index, instruction_index, _ = order.get(row["instruction"], (99, 99, "Other"))
        return (int(row["core"]), configurations.get(row["configuration"], 99),
                row["configuration"], group_index, instruction_index, row["instruction"])

    return [{**row, "group": order.get(row["instruction"], (99, 99, "Other"))[2]}
            for row in sorted(rows, key=key)]


def write_instruction_tables(output, rows):
    """Aligned tab-separated human report plus an unpadded TSV for data tools."""
    ordered = grouped_rows(rows)
    with (output / "instructions.raw.tsv").open("w", newline="", encoding="utf-8") as file:
        writer = csv.DictWriter(file, fieldnames=REPORT_COLUMNS, delimiter="\t")
        writer.writeheader(); writer.writerows(ordered)

    values = [[str(row[column]) for column in REPORT_COLUMNS] for row in ordered]
    widths = [max(len(column), *(len(row[idx]) for row in values))
              for idx, column in enumerate(REPORT_COLUMNS)]
    numeric = {"core", "planned", "passed", "failed", "not_run", "unconfirmed"}

    def line(cells):
        return "\t".join(cell.rjust(width) if column in numeric else cell.ljust(width)
                         for cell, column, width in zip(cells, REPORT_COLUMNS, widths))

    lines = [line(REPORT_COLUMNS), *(line(row) for row in values)]
    (output / "instructions.tsv").write_text("\n".join(lines) + "\n", encoding="utf-8")


def classify(manifest, result, configuration):
    counts = {name: Counter() for name in manifest["coverage"]}
    outcome = result["status"]
    fail_id = result["ledr"]
    valid_failure = outcome == "SELF_FAIL" and 1 <= fail_id <= len(manifest["cases"])
    for case in manifest["cases"]:
        if outcome == "PASS":
            status = "passed"
        elif valid_failure:
            status = "passed" if case["id"] < fail_id else "failed" if case["id"] == fail_id else "not_run"
        else:
            status = "unconfirmed"
        counts[case["instruction"]][status] += 1
    rows = []
    for name, planned in sorted(manifest["coverage"].items()):
        count = counts[name]
        if count["failed"]:
            status = "FAIL"
        elif count["passed"] == planned:
            status = "PASS"
        elif count["unconfirmed"]:
            status = "UNCONFIRMED"
        elif count["passed"]:
            status = "PARTIAL"
        else:
            status = "NOT_RUN"
        row = dict(configuration=configuration, core=result["core"], instruction=name.upper(),
                   status=status, planned=planned,
                   **{key: count[key] for key in ("passed", "failed", "not_run", "unconfirmed")})
        assert sum(row[key] for key in ("passed", "failed", "not_run", "unconfirmed")) == planned
        rows.append(row)
    return rows


def render(rows, result):
    first = rows[0]
    lines = [f"APP05 INSTRUCTIONS core={first['core']} blocks={first['configuration']} app={result['status']}",
             "Results follow ordered fail-fast case IDs; later checks are not counted as PASS.",
             "INSTRUCTION STATUS        PLANNED    PASS    FAIL NOT_RUN UNCONFIRMED"]
    for row in rows:
        lines.append(f"{row['instruction']:<11} {row['status']:<13} {row['planned']:>7} {row['passed']:>7} {row['failed']:>7} {row['not_run']:>7} {row['unconfirmed']:>11}")
    totals = {key: sum(row[key] for row in rows) for key in ("planned", "passed", "failed", "not_run", "unconfirmed")}
    lines.append("TOTAL" + " "*21 + " ".join(f"{totals[key]:>7}" for key in totals))
    lines.append(f"INSTRUCTION SUMMARY: {sum(row['status'] == 'PASS' for row in rows)} PASS, "
                 f"{sum(row['status'] == 'FAIL' for row in rows)} FAIL, "
                 f"{sum(row['status'] not in ('PASS', 'FAIL') for row in rows)} incomplete")
    if result["status"] == "SELF_FAIL":
        manifest = json.loads(MANIFEST.read_text())
        case = next((case for case in manifest["cases"] if case["id"] == result["ledr"]), None)
        if case:
            lines.append(f"FAILED CASE {case['id']}: {case['instruction'].upper()} -- {case['detail']}")
    return "\n".join(lines) + "\n"


def write_reports(results_path, configuration):
    manifest = json.loads(MANIFEST.read_text())
    results = json.loads(results_path.read_text())
    result = next((item for item in results if item["app"] == "app05_instruction"), None)
    if result is None:
        return []
    rows = classify(manifest, result, configuration)
    output = results_path.parent
    (output / "instructions.json").write_text(json.dumps(rows, indent=2) + "\n")
    write_instruction_tables(output, rows)
    report = render(rows, result)
    (output / "instructions.txt").write_text(report, encoding="utf-8")
    print(report, end="")
    return rows


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("Usage: report_app05.py <results.json> <configuration>")
    write_reports(Path(sys.argv[1]), sys.argv[2])
