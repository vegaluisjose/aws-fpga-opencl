# aws-fpga-opencl

This is a hello-world (vector-add) example developed in Xilinx SDAccel. This Makefile should
download and run all necessary code (dependencies) to simulate and build FPGA bitstream.

Few things:

* Tested on Amazon FPGA AMI instace [1.3.5](https://aws.amazon.com/marketplace/pp/B06VVYBLZZ)
* The host code is written in OpenCL
* The kernel code is written in HLS (C/C++)
* Makefile currently support software emulation and hardware build

## sw_emu
1. Run `make sw_emu`

## hw
1. Run `make`
2. Run `make afi_build`
3. Wait until AFI become available, AFI status can be checked with `make afi_status`
4. Switch or connect to the Amazon F1 instance
5. Go to the `out` directory, `cd out`
6. Run `./host vadd.awsxclbin`
