// 30 min sound file
b = Buffer.read(s,"/Volumes/2024-May-Ted-Moore/no-such-thing-as-a-circle/circuit sounds/nand gate 3/audio/01-210202_1619.wav");

b.play;

~seconds = [1,10,30,60,60 * 2, 60 * 5, 60 * 10, 60* 20, 60 * 30];

(
~seconds.do{
	arg sec;
	var bases = Buffer(s);
	var acts = Buffer(s);
	var starttime = thisProcess.tick;
	FluidBufNMF.process(s,b,0,sec * b.sampleRate,bases:bases,activations:acts,components:2,action:{
		"Buffer of % seconds took % seconds to analyze (decompose)".format(sec,thisProcess.tick - starttime).postln;
	});
};
)

/*
Buffer of 1 seconds took 4.91059275 seconds to analyze (decompose)
Buffer of 10 seconds took 4.91059275 seconds to analyze (decompose)
Buffer of 30 seconds took 9.831731417 seconds to analyze (decompose)
Buffer of 60 seconds took 20.381604208 seconds to analyze (decompose)
Buffer of 120 seconds (2min) took 40.98719175 seconds to analyze (decompose) 0.33
Buffer of 300 seconds (5min) took 90.158043583 seconds to analyze (decompose) 0.3
Buffer of 600 seconds (10min) took 204.756666083 seconds to analyze (decompose) 3.4min 0.34
Buffer of 1200 seconds (20min) took 357.308342292 seconds to analyze (decompose) 5.95min 0.29
Buffer of 1800 seconds (30min) took 485.258681292 seconds to analyze (decompose) 8.08min 0.27
*/