import subprocess,time
from pathlib import Path
print("Command: bash 10_sim/run_milestone1.sh +wave",flush=True)
r=subprocess.run(["bash",'/mnt/c/Users/ADMIN/Desktop/CTMT/Projects/Computer_architecture/10_sim/run_milestone1.sh',"+wave"],cwd='/mnt/c/Users/ADMIN/Desktop/CTMT/Projects/Computer_architecture')
Path('/mnt/c/Users/ADMIN/Desktop/CTMT/Projects/Computer_architecture/99_doc/Report/gtk_sessions/terminal.ready').write_text(str(r.returncode))
print("Simulation exit code:",r.returncode,flush=True)
time.sleep(3600)
