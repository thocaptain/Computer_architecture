#!/bin/sh
set -eu
source_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
mkdir -p /home/root/hps_test
cp "$source_dir/hps_calculator" /home/root/hps_test/hps_calculator
cp "$source_dir/hps_calculator_lcd" /home/root/hps_test/hps_calculator_lcd
chmod 755 /home/root/hps_test/hps_calculator /home/root/hps_test/hps_calculator_lcd
printf '%s\n' 'Calculator installed. Load the NEW calculator .sof before running:'
printf '%s\n' 'cd /home/root/hps_test' './hps_calculator_lcd 0xff206000'
