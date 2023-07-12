// ====== bases and activations ========

~drums = Buffer.read(s,FluidFilesPath("Nicol-LoopE-M.wav"));
// first, let's make two new buffers called...
~bases = Buffer(s);
~activations = Buffer(s);
~n_components = 3;

// and we'll explicitly pass these into the process
FluidBufNMF.processBlocking(s,~drums,bases:~bases,activations:~activations,components:~n_components,action:{"done".postln;});

// now we can plot them (yours may end up in a different order!):
~bases.plot;
// the bases are a like a spectral template that FluidBufNMF has found in the source buffer

~activations.plot;
// the activations are the corresponding loudness envelope of each base above. It will look like an amplitude
// envelope follower of the drum hits in the corresponding bases.

// ========= the activations could also be used as an envelope through time ===========

// we'll use 2 components here since we have just two speakers...
FluidBufNMF.processBlocking(s,~drums,bases:~bases,activations:~activations,components:2,action:{"done".postln;});

(
{
	var activation = PlayBuf.ar(2,~activations,BufRateScale.ir(~activations),doneAction:2);
	var sig = LFTri.ar([300,400],0,0.2) * activation;
	sig;
}.play;
)

// note that the samplerate of the ~activations buffer is not a usual one...
~activations.sampleRate

(
{
	var activation = PlayBuf.ar(2,~activations,BufRateScale.ir(~activations),doneAction:2);
	var sig = PinkNoise.ar(0.dbamp);
	sig = FluidNMFFilter.ar(sig,~bases,2) * activation;
	sig;
}.play;
)