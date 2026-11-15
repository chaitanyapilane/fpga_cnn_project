# Nexys 4 demo: assumed 5 pF external load on each LED output.
# Project mode: add to constrs_1, set USED_IN_SYNTHESIS false and
# USED_IN_IMPLEMENTATION true on this file.
set_load 5.000 [get_ports {led[0] led[1] led[2] led[3] led[4] led[5] led[6] led[7]}]
