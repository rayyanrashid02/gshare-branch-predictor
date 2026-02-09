SIM=build/sim
VCD=dump.vcd

RTL=rtl/gshare_predictor.v
TB=tb/tb_gshare.sv

all: sim

sim:
	mkdir -p build
	iverilog -g2012 -o $(SIM) $(RTL) $(TB)
	vvp $(SIM)

wave:
	@echo "If this errors on macOS, open GTKWave manually and load dump.vcd"
	-gtkwave dump.vcd || true

schematic:
	yosys scripts/synth.ys

clean:
	rm -rf build *.vcd