# vadd

## Software emulation
1. Run `make sim target=sw_emu`

## Hardware emulation
1. Run `make sim target=hw_emu`

## Hardware generation
1. Run `make`
1. Run `make afi_build`
1. Wait until AFI become available, AFI status can be checked with `make afi_status`
1. Switch or connect to the Amazon F1 instance
1. Go to the `out` directory, `cd out`
1. Run `./host vadd.awsxclbin`
