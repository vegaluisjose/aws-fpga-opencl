# aws-fpga-opencl

These are examples developed in Xilinx SDAccel. This Makefile should
download and run all necessary code (dependencies) to simulate and build FPGA bitstream.

Few things:

* Tested on Amazon FPGA AMI instace [1.3.5](https://aws.amazon.com/marketplace/pp/B06VVYBLZZ)
* The host code is written in OpenCL
* The kernel code is written in HLS (C/C++)

## Examples
1. `vadd` vector addition
1. `dataflow_loop` dataflow loop
