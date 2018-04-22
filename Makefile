aws_fpga_dir = $(abspath .)/aws-fpga
aws_fpga_ver = b1ed5e951de3442ffb1fc8c7097e7064489e83f1
aws_platform = xilinx_aws-vu9p-f1_1ddr-xpr-2pr_4_0

out_dir = $(abspath .)/out
src_dir = $(abspath .)/src

kernel_name = vadd

default: $(out_dir)/$(kernel_name).xclbin

bucket_name ?= fbit
bucket_dir ?= ocl

afi_status:
	aws ec2 describe-fpga-images --fpga-image-ids afi-059bbfea3a06de54e

afi: $(out_dir)/$(kernel_name)

$(out_dir)/$(kernel_name): $(out_dir)/$(kernel_name).xclbin
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
	bash -c "source $@/sdaccel_setup.sh"

clean:
	-rm -rf *.dir
