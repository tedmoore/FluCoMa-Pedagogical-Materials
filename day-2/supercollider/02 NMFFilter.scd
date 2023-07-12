// ================================ NMF Filter ================================================

// we'll use the drum loop again
~drums = Buffer.read(s,FluidFilesPath("Nicol-LoopE-M.wav"));

// make some activations and bases
~activations = Buffer(s);
~bases = Buffer(s);
~n_components = 3;

// do the analysis
FluidBufNMF.processBlocking(s,~drums,bases:~bases,activations:~activations,components:~n_components,action:{"done".postln;});

// first we'll just send the original back through
(
y = {
	arg which = 0;
	var src = PlayBuf.ar(1,~drums,BufRateScale.ir(~drums),doneAction:2);
	var sig = FluidNMFFilter.ar(src,~bases,~n_components);
	Select.ar(which,sig).dup;
}.play;
)

// hear the other two components
y.set(\which,1);
y.set(\which,2);

// if we play a different source through FluidNMFFilter, it will try to decompose that real-time signal according to the bases
// it is given (in our case the bases from the drum loop)
~song = Buffer.readChannel(s,FluidFilesPath("Tremblay-beatRemember.wav"),channels:[0]);

(
y = {
	arg which = 0;
	var src = PlayBuf.ar(1,~song,BufRateScale.ir(~song),doneAction:2);
	var sig = FluidNMFFilter.ar(src,~bases,~n_components);
	Select.ar(which,sig).dup;
}.play;
)

y.set(\which,1);
y.set(\which,2);

// ========================== Live source separation for adding separate FX ========================

FluidBufNMF.processBlocking(s,~drums,bases:~bases,activations:~activations,components:3,action:{"done".postln;});

(
{
	var src = PlayBuf.ar(1,~drums,BufRateScale.ir(~drums),loop:1);
	var sig = FluidNMFFilter.ar(src,~bases,3);
	var mix;
	mix = Splay.ar(sig);
	mix = mix + GVerb.ar(sig[0],100,7,0.9,drylevel:0,mul:-10.dbamp);
	mix = mix + CombC.ar(sig[1],0.2,LFTri.kr(0.1).range(0.0,0.2));
	mix = mix + CombN.ar(sig[2],0.1,[0.09,0.1],1.0);
	mix;
}.play;
)