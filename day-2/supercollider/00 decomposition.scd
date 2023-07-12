// =============== decompose some sounds ===============

// let's decompose the drum loop that comes with the FluCoMa extension:
~drums = Buffer.read(s,FluidFilesPath("Nicol-LoopE-M.wav"));

// hear the original mono sound file to know what we're working with
~drums.play;

// an empty buffer for the decomposed components to be written into:
~resynth = Buffer(s);

// how many components we want FluidBufNMF to try to decompose the buffer into:
~n_components = 3;

// process it:
FluidBufNMF.processBlocking(s,~drums,resynth:~resynth,components:~n_components,resynthMode:1,action:{"done".postln;});

// once it is done, play the separated components one by one (with a second of silence in between)
// (yours may end up in a different order)
(
fork{
	~n_components.do{
		arg i;
		"decomposed part #%".format(i+1).postln;
		{
			PlayBuf.ar(~n_components,~resynth,BufRateScale.ir(~resynth),doneAction:2)[i].dup;
		}.play;
		(~drums.duration + 1).wait;
	}
};
)