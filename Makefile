aws_fpga_dir = $(abspath .)/aws-fpga
aws_fpga_ver = b1ed5e951de3442ffb1fc8c7097e7064489e83f1
aws_platform = xilinx_aws-vu9p-f1_1ddr-xpr-2pr_4_0

synth_dir = $(abspath .)/synth
src_dir = $(abspath .)/src

kernel_name = vadd

all: $(synth_dir)/$(kernel_name).xo

# xocc compile options
# -c compile mode
# -xp additional parameters
# -s save intermediate files
# -k kernel to be compiled (required for c/c++ kernel and optional for opencl ones)
# -t compile target sw_emu, hw_wmu, or hw
$(synth_dir)/$(kernel_name).xo: $(src_dir)/$(kernel_name).cpp | $(aws_fpga_dir)
	mkdir -p $(dir $@)
	xocc -c -s \
	--platform $(aws_fpga_dir)/SDAccel/aws_platform/$(aws_platform)/$(aws_platform).xpfm \
	-t hw \
	-o $@ \
	-k $(kernel_name) \
	--xp param:compiler.preserveHlsOutput=1 \
	--xp param:compiler.generateExtraRunData=true \
	$<

# clone aws-fpga repository to a specific commit
$(aws_fpga_dir):
	git clone https://github.com/aws/aws-fpga.git $@
	cd $@ && git checkout $(aws_fpga_ver) -b aws_hw_18
	bash -c "source $@/sdaccel_setup.sh"

clean:
	-rm -rf *.dir
