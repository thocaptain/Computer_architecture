#!/bin/sh
set -eu
source_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
mkdir -p /home/root/hps_test
cp "$source_dir/hps_scientific" /home/root/hps_test/hps_scientific
cp "$source_dir/hps_scientific_lcd" /home/root/hps_test/hps_scientific_lcd
chmod 755 /home/root/hps_test/hps_scientific /home/root/hps_test/hps_scientific_lcd
printf '%s\n' 'Scientific programs installed. First load the .sof containing scientific_hps.mem.'
printf '%s\n' 'cd /home/root/hps_test' './hps_scientific_lcd 0xff206000'
