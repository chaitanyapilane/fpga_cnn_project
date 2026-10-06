# Results tables

## 1. Accuracy (first 2,000 test images)
| Network | Dataset | Float | Full-integer (INT8, int32 bias, fixed-point requant) |
|---|---|---|---|
| LeNet-5 | MNIST | 97.80% | 97.85% |
| SmallCNN | CIFAR-10 | 70.50% | 70.50% |

Full test set, float / INT8 weights only: LeNet 98.48% / 98.48%, SmallCNN 69.66% / 69.58%.

## 2. Scheduler sweep (RTL, LeNet period varied; failures = late + dropped)
| Policy | 6k | 8k | 12k | 20k | SmallCNN |
|---|---|---|---|---|---|
| Dynamic EDF | 2/33 | 0/33 | 0/33 | 0/33 | 2/4, 1/4, 0/4, 0/4 |
| Static 2+2 | 33/33 | 33/33 | 33/33 | 33/33 | 0/4 |
| Static 3+1 | 0/33 | 0/33 | 0/33 | 0/33 | 4/4 |

## 3. Concurrent run on 4 tiles (LeNet L1 + SmallCNN S2, real data, 1,280 outputs bit-exact)
| Mode | LeNet latency (deadline 3,000) | SmallCNN latency (deadline 4,000) | Both met |
|---|---|---|---|
| Dynamic EDF | 2,569 | 3,717 | yes |
| Static 1+3 | 10,245 | 1,553 | no |
| Static 2+2 | 5,125 | 2,309 | no |
| Static 3+1 | 3,425 | 4,613 | no |

Makespan under EDF: 3,718 cycles vs ideal 3,712.

## 4. Resources (Yosys synth_xilinx estimates, not place-and-route)
| Block | DSP48E1 | FDRE | LUT | CARRY4 | RAM32M |
|---|---|---|---|---|---|
| Tile (16 MACs) | 16 | 71 | 35 | 8 | 0 |
| Multi-network top (4 tiles + EDF + tag FIFOs) | 64 | 602 | 473 | 124 | 8 |
| Post-processing | 2 | 3 | 42 | 20 | 0 |
| 2x2 pool | 0 | 9 | 46 | 3 | 0 |
| Line-buffer pool | 0 | 28 | 45 | 4 | 2 |
| Argmax | 0 | 45 | 34 | 4 | 0 |
| **Total** | **66** | **687** | **598** | **135** | **10** |

## 5. Verification coverage
LeNet: all 5 layers bit-exact on the tile; conv1 and conv2 chains (tile, bias/ReLU/requant, pool) match; FC1/FC2/FC3 plus argmax predict digit 7 (true label 7).
SmallCNN: 778 sampled outputs bit-exact.
