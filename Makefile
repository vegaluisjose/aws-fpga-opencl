# flow
# 1. Build xclbin - make
# 2. Generate AFI - make afi
# 3. Check AFI status - make afi_status
# 4. Compile host code - make build_host

aws_fpga_dir = $(abspath .)/aws-fpga
aws_fpga_ver = b1ed5e951de3442ffb1fc8c7097e7064489e83f1
aws_platform = xilinx_aws-vu9p-f1_1ddr-xpr-2pr_4_0

export AWS_FPGA_REPO_DIR = $(aws_fpga_dir)
export HDK_DIR = $(aws_fpga_dir)/hdk
export HDK_SHELL_DIR = $(aws_fpga_dir)/hdk/common/shell_stable

bucket_name ?= fbit
bucket_dir ?= ocl

out_dir = $(abspath .)/out
src_dir = $(abspath .)/src
run_dir = $(abspath .)/run # FIXME required for non-4ddr-systems, due to a xilinx-aws-bug in xcl2

kernel_name = vadd
host_name = host

default: $(out_dir)/$(kernel_name).xclbin

build_host: $(out_dir)/$(host_name) $(run_dir)/$(fixme_xilinx_name_format).awsxclbin

$(run_dir)/$(host_name): $(src_dir)/$(host_name).cpp
	xcpp -Wall -O0 -g \
	-I$(XILINX_SDX)/runtime/include/1_2 \
	-I$(aws_fpga_dir)/SDAccel/examples/xilinx/libs/xcl2 \
	-lOpenCL -pthread \
	-L$(XILINX_SDX)/runtime/lib/x86_64 \
	-L$(XILINX_SDX)/lib/lnx64.o \
	-o $@ \
	$(aws_fpga_dir)/SDAccel/examples/xilinx/libs/xcl2/xcl2.cpp \
	$<

# FIXME

fixme_xilinx_name_format = $(kernel_name).hw.xilinx_aws-vu9p-f1_4ddr-xpr-2pr_4_0

$(run_dir)/$(fixme_xilinx_name_format).awsxclbin: $(out_dir)/$(kernel_name).awsxclbin
	cp $< $@

afi_id = $(shell cat $(shell ls -t *_afi_id.txt | head -n 1) | sed -nr "s/.*(afi-[0-9a-zA-Z]*).*/\1/p")

afi_status:
	aws ec2 describe-fpga-images --fpga-image-ids $(afi_id)

afi_delete:
	aws ec2 --region us-west-2 delete-fpga-image --fpga-image-id $(afi_id)

afi: $(out_dir)/$(kernel_name).awsxclbin

$(out_dir)/$(kernel_name).awsxclbin: $(out_dir)/$(kernel_name).xclbin
	$(aws_fpga_dir)/SDAccel/tools/create_sdaccel_afi.sh \
	-xclbin=$< \
	-o=$(out_dir)/$(kernel_name) \
	-s3_bucket=$(bucket_name) \
	-s3_dcp_key=$(bucket_dir) \
	-s3_logs_key=$(bucket_dir)/afi.log

# xocc compile options
# -c compile mode
# -xp additional parameters
# -s save intermediate files
# -k kernel to be compiled (required for c/c++ kernel and optional for opencl ones)
# -t compile target sw_emu, hw_wmu, or hw
# -l link mode

$(out_dir)/$(kernel_name).xclbin: $(out_dir)/$(kernel_name).xo
	xocc -l -s \
	--platform $(aws_fpga_dir)/SDAccel/aws_platform/$(aws_platform)/$(aws_platform).xpfm \
	-t hw \
	-o $@ \
	--xp param:compiler.preserveHlsOutput=1 \
	--xp param:compiler.generateExtraRunData=true \
	$<

$(out_dir)/$(kernel_name).xo: $(src_dir)/$(kernel_name).cpp | $(aws_fpga_dir)
	mkdir -p $(dir $@)
	xocc -c -s \
	--platform $(aws_fpga_dir)/SDAccel/aws_platform/$(aws_platform)/$(aws_platform).xpfm \
	-t hw \
	-o $@ \
	-k $(kernel_name) \
	--xp param:compiler.preserveHlsOutput=1 \
	--xp param:compiler.generateExtraRunData=true \
	$<

# clone aws-fpga repository
$(aws_fpga_dir):
	git clone https://github.com/aws/aws-fpga.git $@
	cd $@ && git checkout $(aws_fpga_ver) -b aws_hw_18
	cd $@ && bash -c "source sdaccel_setup.sh"
	cd $@ && bash -c "source hdk_setup.sh"

clean:
	-rm -rf *.dir $(run_dir) $(out_dir) *.txt *.tar *.bit *.bin *.xml to_aws $(aws_fpga_dir)
