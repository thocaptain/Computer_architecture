"""Summarize actual per-app results and automatically compare baseline cycles."""
import csv
import json
from pathlib import Path
import sys
from report_app05 import classify, write_instruction_tables

ROOT = Path(__file__).resolve().parents[2]
BASE = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else ROOT / "02_test" / "Milestone1" / "cpu"


def summarize():
    phases = list(csv.DictReader((BASE / "summary.tsv").open(), delimiter="\t"))
    records = []
    manifest = json.loads((ROOT / "02_test" / "Milestone1" / "apps" / "app05_manifest.json").read_text())
    cases = {case["id"]: case for case in manifest["cases"]}
    errors = []
    for phase in phases:
        config, core = phase["configuration"], int(phase["core_mode"])
        path = BASE / f"{config}_mode{core}" / "results.json"
        try:
            items = json.loads(path.read_text())
        except (ValueError, FileNotFoundError):
            errors.append(f"{config} core {core}: {phase['status']}, no valid simulation results")
            continue
        for item in items:
            item["configuration"] = config
            if item["status"] == "SELF_FAIL" and item["app"] == "app05_instruction":
                case = cases.get(item["ledr"], {})
                item["failure_detail"] = case.get("detail", "unknown case")
                item["failure_instruction"] = case.get("instruction", "unknown")
            records.append(item)
    baselines = {(r["core"], r["app"]): r for r in records if r["configuration"] == "baseline"}
    for item in records:
        baseline = baselines.get((item["core"], item["app"]))
        item["cycle_delta"] = item["cycles"] - baseline["cycles"] if baseline else None
        item["matches_baseline"] = all(item[key] == baseline[key] for key in ("status", "cycles", "ledr", "ledg")) if baseline else None
    (BASE / "app_results.json").write_text(json.dumps(records, indent=2) + "\n")
    instruction_rows = []
    for record in records:
        if record["app"] == "app05_instruction":
            instruction_rows.extend(classify(manifest, record, record["configuration"]))
    if instruction_rows:
        (BASE / "instructions.json").write_text(json.dumps(instruction_rows, indent=2) + "\n")
        write_instruction_tables(BASE, instruction_rows)
    columns = ["configuration", "core", "app", "status", "cycles", "cycle_delta", "ledr", "expected_ledr", "ledg", "matches_baseline"]
    with (BASE / "cycle_comparison.tsv").open("w", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=columns, delimiter="\t", extrasaction="ignore")
        writer.writeheader(); writer.writerows(records)
    lines = ["# Full CPU app results", "", "Each row is an actual ROM execution with a fresh model.", "",
             "| Core | App | Blocks | Status | Cycles | Delta vs original | Matches original result |",
             "| --- | --- | --- | --- | ---: | ---: | --- |"]
    for r in records:
        delta = r["cycle_delta"] if r["cycle_delta"] is not None else "not run"
        lines.append(f"| {r['core']} | {r['app']} | {r['configuration']} | {r['status']} | {r['cycles']:,} | {delta} | {r['matches_baseline']} |")
    lines.extend(["", "Baseline equality does not imply PASS: the original CPU may fail the same app.", ""])
    failures = [r for r in records if r["status"] != "PASS"]
    for r in failures:
        lines.append(f"- Core {r['core']} / {r['configuration']} / {r['app']}: {r['status']}, LEDR={r['ledr']} ({r.get('failure_instruction', '')}: {r.get('failure_detail', '')}).")
    lines.extend(f"- {error}" for error in errors)
    lines.extend(["", f"App 05: {manifest['expected_ledr']:,} checks, {len(manifest['coverage'])} instructions, {manifest['bytes']:,} ROM bytes.",
                  "Coverage: " + manifest["scope"], "",
                  "PASS requires the exact app signature in LEDR and exact core-width status in LEDG before timeout.",
                  "Modes 0..2: PASS=0x600d, SELF_FAIL=0x0bad. Mode 3: PASS=0x00d, SELF_FAIL=0x1ad.",
                  "all_suit LEDR=0x3fff; app05 LEDR=" + hex(manifest["expected_ledr"]) + ".",
                  "Missing ROM, lint/build errors, timeout, any other LEDG, or incorrect LEDR are failures.",
                  "The program writes LEDR first and LEDG last. These conditions are identical for async and sync memory.", ""])
    if failures and all(r.get("failure_instruction") == "jalr" and r["ledr"] == manifest["expected_ledr"] for r in failures):
        lines.extend(["## Failure diagnosis", "",
                      "All observed app failures are the final JALR odd-target case. The single-cycle",
                      "CPU clears bit 0; the pipeline PC_EX_ALU path in 00_src/rv32i.sv assigns",
                      "EX_alu_res directly to pc. The instruction ROM discards low address bits, so",
                      "AUIPC at the target is used to expose the incorrect odd PC. This failure",
                      "occurs in the original baseline and in both replacement-memory configurations.",
                      "The old pipeline PC logic is unchanged by this task.", "",
                      "LEDR=0xf8ec is both the success signature and the last case ID. LEDG=0x0bad",
                      "(or 0x1ad in mode 3) still means SELF_FAIL, regardless of matching LEDR.", ""])
    (BASE / "RESULTS.md").write_text("\n".join(lines), encoding="utf-8")
    print(f"CPU report: {len(records)} app runs, {len(failures)} not PASS; {BASE / 'RESULTS.md'}")
    differences = [r for r in records if r["matches_baseline"] is False]
    if errors or differences:
        raise SystemExit("Integration errors or differences versus baseline; see RESULTS.md")


if __name__ == "__main__":
    summarize()
