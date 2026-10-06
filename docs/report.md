# Reconfigurable Multi-CNN FPGA Accelerator with Dynamic Resource Scheduling

## 1. Introduction
Edge systems often run several CNNs at once with different workloads and deadlines. A fixed split of compute resources between networks either starves the heavy network or wastes capacity when the light one is idle. This project builds a small INT8 accelerator whose compute tiles are assigned to networks at runtime by an earliest-deadline-first (EDF) scheduler, and compares it against static splits.

Two networks are used: LeNet-5 (MNIST, 281,640 MACs per inference) and SmallCNN (CIFAR-10, 2,811,904 MACs, about 10x heavier).

## 2. Architecture
See results/architecture.png.
- **Tile:** 16 INT8 multipliers, an adder tree and a 32-bit accumulator, 3 pipeline stages. One tile produces one dot-product beat of 16 MACs per cycle.
- **Array:** 4 tiles (64 MACs). Any tile can start an output of either network on the cycle after it finishes one.
- **Controller (multi_top):** per-output EDF dispatch. A free tile takes the next output of the job with the earliest absolute deadline. Each tile has a small in-order tag FIFO, so results are labelled with job and output index without draining the pipeline when a tile switches networks.
- **Memory interface:** the controller emits (job, address) per tile and expects data one cycle later, like a synchronous-read BRAM.
- **Post-processing:** bias add, ReLU, fixed-point requantization floor((x*mult + 32768)/65536) clamped to 0..127, a streaming 2x2 max-pool with a line buffer, and an argmax unit for the final scores.

## 3. Method
**Quantization.** Weights are INT8, symmetric, per-layer scale. Biases are int32. Activations are requantized to int8 between layers with a 16-bit fixed-point multiplier. Accuracy is measured with this full-integer pipeline, so it is the number the hardware reproduces.

**Scheduling study.** A Python model compared static 2+2, fair-share and strict EDF. An RTL scheduler then reproduced the strict-EDF result, with static baselines and a period sweep. A job counts as failed if it finishes late or is dropped because its network's slot is still busy at the next arrival.

**Verification.** Every hardware block is checked against an independent integer reference derived from the PyTorch weights, using self-checking Verilog testbenches in Icarus Verilog.

## 4. Results
Full tables are in results/tables.md.

**Accuracy (first 2,000 test images).** LeNet: 97.80% float, 97.85% full-integer. SmallCNN: 70.50% float, 70.50% full-integer. On the full test sets, INT8 weights alone give 98.48% (LeNet) and 69.58% against 69.66% float (SmallCNN).

**Concurrent run (LeNet layer 1 plus SmallCNN layer 2 on 4 tiles, 1,280 outputs, all bit-exact).**

| Mode | LeNet latency (deadline 3,000) | SmallCNN latency (deadline 4,000) | Both met |
|---|---|---|---|
| Dynamic EDF | 2,569 | 3,717 | yes |
| Static 1+3 | 10,245 | 1,553 | no |
| Static 2+2 | 5,125 | 2,309 | no |
| Static 3+1 | 3,425 | 4,613 | no |

No static split meets both deadlines. EDF does, with a makespan of 3,718 cycles against an ideal 3,712, so the array is almost fully used. The synthesizable controller matched the behavioral model to within one cycle.

**Period sweep (RTL scheduler).** At LeNet periods of 12k and 20k cycles, EDF meets all deadlines for both networks. At 8k, one SmallCNN job is dropped. At 6k the system is overloaded and EDF fails 2 of 33 LeNet jobs and 2 of 4 SmallCNN jobs. Static 2+2 fails every LeNet job, and static 3+1 fails every SmallCNN job at every period. One unexpected result: under overload EDF did not always favour LeNet, because SmallCNN's absolute deadline eventually becomes the earlier one. This explanation is likely but was not confirmed with a waveform.

**Resources (Yosys synth_xilinx estimates, not place-and-route).**

| Block | DSP48E1 | FDRE | LUT | CARRY4 | RAM32M |
|---|---|---|---|---|---|
| Tile | 16 | 71 | 35 | 8 | 0 |
| Multi-network top (4 tiles, EDF, tag FIFOs) | 64 | 602 | 473 | 124 | 8 |
| Post-processing | 2 | 3 | 42 | 20 | 0 |
| 2x2 pool | 0 | 9 | 46 | 3 | 0 |
| Line-buffer pool | 0 | 28 | 45 | 4 | 2 |
| Argmax | 0 | 45 | 34 | 4 | 0 |
| **Total** | **66** | **687** | **598** | **135** | **10** |

The first controller version used 72 DSPs because the address multiply was mapped to DSPs. Replacing it with shift-and-add brought the total to 64 for the array, at a cost of about 67 LUTs and 44 flip-flops.

**LeNet functional check.** All 5 layers are bit-exact on the tile. The conv1 chain (864 activations) and conv2 chain (256 activations) match the reference through bias, ReLU, requantization and pooling. FC1, FC2 and FC3 plus argmax predict digit 7 for MNIST test image 0, whose label is 7.

## 5. Limitations
- Layers were verified independently with Python-generated inputs. There was no single chained run with on-chip activation buffers, and LeNet was not run through the EDF controller layer by layer.
- The functional check of the full LeNet path used one image. Accuracy figures come from the Python integer model.
- SmallCNN was verified on 778 sampled outputs, not on the full network.
- Memory bandwidth is idealized: every tile reads 256 bits per cycle with no BRAM or DMA limits. On a real device this needs banked or replicated BRAM.
- One post-processing unit cannot keep up with four tiles on conv1 (2 beats per output). Real use would need several units.
- Arrival times, deadlines and job sizes are module parameters, not host-programmed registers, and the shift-add addressing is hard-wired to 10 and 18 beats per output.
- The earlier pe_array module (owner tags changeable only when idle) was replaced by the tag-FIFO design in multi_top, which avoids a drain gap on network switches.
- There was no FPGA board, so there are no timing, power or place-and-route results. The resource numbers are Yosys estimates.
- The scheduler operates at output granularity in the concurrent run, and at chunk granularity in the earlier sweep. The two are not directly comparable.

## 6. Future work
Chained multi-layer execution with on-chip activation buffers, a BRAM bandwidth model, a per-network job queue instead of dropping arrivals, host-programmable deadlines, full SmallCNN verification, and Vivado timing, power and on-board tests.

## 7. Reproducing the results
scripts/count_macs.py, scripts/sched_sim.py, scripts/int8_lenet.py, scripts/int8_smallcnn.py and scripts/make_report_tables.py, plus the testbenches in tb/. Tools: Icarus Verilog, Yosys 0.33, PyTorch (CPU), Python 3.12.
