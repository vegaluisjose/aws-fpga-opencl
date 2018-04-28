# flow
# 1. Build xclbin - make
# 2. Generate AFI - make afi_build
# 3. Check AFI status - make afi_status
# 4. Compile host code - make host_build

aws_fpga_dir = $(abspath .)/aws-fpga
aws_fpga_ver = b1ed5e951de3442ffb1fc8c7097e7064489e83f1
aws_platform = xilinx_aws-vu9p-f1_1ddr-xpr-2pr_4_0

export AWS_FPGA_REPO_DIR = $(aws_fpga_dir)
export HDK_DIR = $(aws_fpga_dir)/hdk
export HDK_SHELL_DIR = $(aws_fpga_dir)/hdk/common/shell_stable

ifeq ($(MAKECMDGOALS),sw_emu)
target = sw_emu
export LD_LIBRARY_PATH:=$(LD_LIBRARY_PATH):$(XILINX_SDX)/lib/lnx64.o
export XCL_EMULATION_MODE=sw_emu
else
target = hw
endif

bucket_name ?= fbit
bucket_dir ?= ocl

out_dir = $(abspath .)/out
sw_emu_dir = $(abspath .)/sw_emu
src_dir = $(abspath .)/src

# FIXME required for non-4ddr-systems, due to a xilinx-aws-bug in xcl2
# xlc2 has a function for finding automatically awsxclbin file when
# host is executed. the function is called find_binary_file and it is
# located at aws-fpga/SDAccel/xilinx/libs/xcl2/xcl2.cpp
runtime_dir = $(abspath .)/runtime
fixme_xilinx_name_format = $(kernel_name).hw.xilinx_aws-vu9p-f1_4ddr-xpr-2pr_4_0

kernel_name = vadd
host_name = host

default: $(out_dir)/$(kernel_name).xclbin

.PHONY:sw_emu
sw_emu: $(runtime_dir)/$(host_name) $(out_dir)/$(kernel_name).xclbin
	mkdir -p $(sw_emu_dir)
	cp $(runtime_dir)/$(host_name) $(sw_emu_dir)
	cp $(out_dir)/$(kernel_name).xclbin $(sw_emu_dir)/$(kernel_name).sw_emu.$(aws_platform).xclbin
	cd $(sw_emu_dir) && emconfigutil --platform $(aws_fpga_dir)/SDAccel/aws_platform/$(aws_platform)/$(aws_platform).xpfm --nd 1
	cd $(sw_emu_dir) && ./$(host_name)

host_build: $(runtime_dir)/$(host_name)

$(runtime_dir)/$(host_name): $(src_dir)/host.cpp | $(runtime_dir) $(aws_fpga_dir)
	xcpp -Wall -O0 -g \
	-I$(XILINX_SDX)/runtime/include/1_2 \
	-I$(aws_fpga_dir)/SDAccel/examples/xilinx/libs/xcl2 \
	-lOpenCL -pthread \
	-L$(XILINX_SDX)/runtime/lib/x86_64 \
	-L$(XILINX_SDX)/lib/lnx64.o \
	-o $@ \
	$(aws_fpga_dir)/SDAccel/examples/xilinx/libs/xcl2/xcl2.cpp \
	$<

# get afi-id from text file
afi_id = $(shell cat $(shell ls -t *_afi_id.txt | head -n 1) | sed -nr "s/.*(afi-[0-9a-zA-Z]*).*/\1/p")

afi_status:
	aws ec2 describe-fpga-images --fpga-image-ids $(afi_id)

afi_delete:
	aws ec2 --region us-west-2 delete-fpga-image --fpga-image-id $(afi_id)

afi_build: $(out_dir)/$(kernel_name).xclbin | $(runtime_dir) $(aws_fpga_dir)
	$(aws_fpga_dir)/SDAccel/tools/create_sdaccel_afi.sh \
	-xclbin=$< \
	-o=$(out_dir)/$(kernel_name) \
	-s3_bucket=$(bucket_name) \
	-s3_dcp_key=$(bucket_dir) \
	-s3_logs_key=$(bucket_dir)/afi.log
	cp $(out_dir)/$(kernel_name).awsxclbin $(runtime_dir)/$(fixme_xilinx_name_format).awsxclbin

$(runtime_dir):
	mkdir -p $@

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
	-t $(target) \
	-o $@ \
	--xp param:compiler.preserveHlsOutput=1 \
	--xp param:compiler.generateExtraRunData=true \
	$<

$(out_dir)/$(kernel_name).xo: $(src_dir)/$(kernel_name).cpp | $(aws_fpga_dir)
	mkdir -p $(dir $@)
	xocc -c -s \
	--platform $(aws_fpga_dir)/SDAccel/aws_platform/$(aws_platform)/$(aws_platform).xpfm \
	-t $(target) \
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

clean_all: clean_out clean_aws clean_sw_emu clean_xocc clean_runtime clean_afi

clean_out:
	-rm -rf $(out_dir)

clean_aws:
	-rm -rf $(aws_fpga_dir)

clean_sw_emu:
	-rm -rf $(sw_emu_dir)

clean_xocc:
	-rm -rf *.dir

clean_runtime:
	-rm -rf $(runtime_dir)

clean_afi:
	-rm -rf *.txt *.tar *.bit *.bin *.xml to_aws
