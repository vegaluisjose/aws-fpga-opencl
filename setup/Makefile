include Makefile.include

default: $(AWS_FPGA_REPO_DIR)

$(AWS_FPGA_REPO_DIR):
	git clone https://github.com/aws/aws-fpga.git $@
	cd $@ && git checkout $(AWS_FPGA_VERSION) -b aws_hw_18
	cd $@ && bash -c "source sdaccel_setup.sh"
	cd $@ && bash -c "source hdk_setup.sh"

clean:
	-rm -rf $(AWS_FPGA_REPO_DIR)
