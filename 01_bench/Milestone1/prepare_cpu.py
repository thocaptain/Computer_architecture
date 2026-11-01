"""Prepare isolated CPU file lists; never rewrite the legacy CPU RTL.

Only the two conflicting lab module declarations are renamed in generated copies.
All datapath bodies are copied verbatim from the tested Milestone1 sources.
"""
from pathlib import Path
import re


def write_if_changed(path: Path, content: str) -> None:
    if not path.exists() or path.read_text(encoding="utf-8") != content:
        path.write_text(content, encoding="utf-8")


def prepare() -> None:
    root = Path(__file__).resolve().parents[2]
    src = root / "00_src" / "Milestone1"
    output = root / "02_test" / "Milestone1" / "cpu"
    generated = output / "generated"
    generated.mkdir(parents=True, exist_ok=True)

    # Bench-only ROM supports actual runtime program selection, for both baseline
    # and replacements. Original inst_mem.sv ignores +PROG and remains unchanged.
    rom = (root / "00_src" / "inst_mem.sv").read_text()
    rom = rom.replace('    // Init mem', '    string program_path;\n    integer program_file;\n    // Init mem')
    rom = rom.replace('$readmemh(`INST_MEM_PATH, mem);', '''if (!$value$plusargs("PROG=%s", program_path))
            program_path = `INST_MEM_PATH;
        program_file = $fopen(program_path, "r");
        if (program_file == 0) $fatal(1, "Cannot open CPU ROM: %s", program_path);
        $fclose(program_file);
        $readmemh(program_path, mem);''')
    write_if_changed(generated / "inst_mem.sv", rom)
    # The exhaustive app needs a larger instruction ROM. Change only simulation
    # wrapper capacity; baseline and replacements get exactly the same wrapper.
    top = (root / "bench_CPU" / "bin" / "top.sv").read_text()
    top = top.replace('.INST_MEM_ADDR_W(10)', '.INST_MEM_ADDR_W(22)')
    for name in ('rv32i_pipeline_stall', 'rv32i_pipeline_hazard'):
        top = top.replace(f'{name} cpu (', f'{name} #(.INST_MEM_ADDR_W(22)) cpu (')
    write_if_changed(generated / "top.sv", top)
    synth_top = (root / "00_src" / "TOP_SYNTH.sv").read_text()
    synth_top = synth_top.replace('.INST_MEM_ADDR_W(10)', '.INST_MEM_ADDR_W(22)')
    write_if_changed(generated / "TOP_SYNTH.sv", synth_top)

    for original in ("alu", "regfile"):
        body = (src / f"{original}.sv").read_text(encoding="utf-8")
        renamed, count = re.subn(
            rf"(?m)^module\s+{original}\b", f"module milestone1_{original}", body
        )
        if count != 1:
            raise RuntimeError(f"Expected exactly one module declaration: {original}")
        write_if_changed(generated / f"milestone1_{original}.sv", renamed)

    additions = [
        src / "cpu_pkg.sv",
        src / "adder.sv",
        src / "magnitude_comparator.sv",
        src / "shifter.sv",
        generated / "milestone1_alu.sv",
        generated / "milestone1_regfile.sv",
        src / "data_mem_async.sv",
        src / "data_mem_sync.sv",
    ]
    replacements = {name: src / "cpu" / name for name in
                    ("alu.sv", "branch_comp.sv", "regfile.sv", "data_mem.sv")}
    lines = []
    baseline = []
    replaced = set()
    for line in (root / "bench_CPU" / "filelist").read_text().splitlines():
        name = Path(line.strip()).name
        if name in ('inst_mem.sv', 'TOP_SYNTH.sv'):
            line = (generated / name).as_posix()
        baseline.append(line)
        if name in replacements and not line.lstrip().startswith(("#", "+", "-")):
            lines.append(replacements[name].as_posix())
            replaced.add(name)
        else:
            lines.append(line)
        if line.strip() == "../00_src/rv32i_pkg.sv":
            lines.extend(path.as_posix() for path in additions)
    if replaced != set(replacements):
        raise RuntimeError(f"Incomplete CPU replacements: {replaced}")
    if not any("cpu_pkg.sv" in line for line in lines):
        raise RuntimeError("Cannot locate rv32i_pkg.sv in the CPU filelist")
    write_if_changed(output / "filelist", "\n".join(lines) + "\n")
    write_if_changed(output / "baseline_filelist", "\n".join(baseline) + "\n")
    print(f"Prepared CPU integration: {output}")


if __name__ == "__main__":
    prepare()
