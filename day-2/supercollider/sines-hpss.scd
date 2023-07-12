// ===================================== hpss =======================================

// try it with some straight ahead drums:
b = Buffer.read(s,FluidFilesPath("Nicol-LoopE-M.wav"));

// hear original
b.play;

(
y = {
	arg which = 0;
	var src = PlayBuf.ar(1,b,BufRateScale.kr(b),loop:1);
	var sig = FluidHPSS.ar(src,17,31,maskingMode:0);
	Select.ar(which,sig).dup;
}.play;
)

y.set(\which,1); // hear percussive part
y.set(\which,0); // switch back to harmonic part

// something maybe a bit more interesting

b = Buffer.readChannel(s,FluidFilesPath("Tremblay-ASWINE-ScratchySynth-M.wav"),channels:[0]);

// hear original
b.play;

// process the "harmonic" part separately from the "percussive" part
(
y = {
	arg which = 1;
	var src = PlayBuf.ar(1,b,BufRateScale.kr(b),loop:1);
	var harm, perc, residual;

	// FluidHPSS will always output a resdiual stream, but if using maskingMode 0 or 1, the residual will be silent.
	# harm, perc, residual = FluidHPSS.ar(src,37,11,maskingMode:1);
	harm = PitchShift.ar(harm,pitchRatio:LFDNoise0.kr(1).midiratio);
	harm = Pan2.ar(harm,SinOsc.kr(0.3));
	harm = FreeVerb2.ar(harm[0],harm[1],0.9,0.9,0.1);
	harm + Pan2.ar((PitchShift.ar(perc,pitchRatio:0.2) * 10).softclip * 0.3,LFDNoise0.kr(1));
}.play;
)

// ============================ sines =======================================

~src = Buffer.readChannel(s,FluidFilesPath("Tremblay-BeatRemember.wav"),channels:[0]);

(
~synth = {
    arg which = 0, detectionThreshold = -96, minTrackLen = 15;
    var src = PlayBuf.ar(1,~src,BufRateScale.ir(~src),loop:1);
    var sines, residual;
    # sines, residual = FluidSines.ar(src,detectionThreshold:detectionThreshold,minTrackLen:minTrackLen);
    Select.ar(which,[sines,residual]).dup;
}.play;
)

~synth.set(\which,1) // residual
~synth.set(\which,0) // back to sinusoids

// try some different parameters

// tracks can be short but the detection threshold is higher than the default
~synth.set(\detectionThreshold,-40,\minTrackLen,1)

// increase the minimum track length
~synth.set(\detectionThreshold,-40,\minTrackLen,15)

// lower the threshold but increase the track length drastically
~synth.set(\detectionThreshold,-80,\minTrackLen,50)

// increase the threshold drastically but lower the minimum track length
~synth.set(\detectionThreshold,-24,\minTrackLen,1)

// fluid sine feature

(
var buf = Buffer.read(s,FluidFilesPath("Harker-DS-TenOboeMultiphonics-M.wav"));

x = {
    arg nbPeaks = 10, t_hold = 1;
    var source = PlayBuf.ar(1, buf, loop: 1);
    var analysis = Latch.kr(FluidSineFeature.kr(source,numPeaks: nbPeaks, maxNumPeaks: 50),t_hold);
    var resynth = SinOsc.ar(analysis[Array.iota(50)], mul: analysis[Array.iota(50) + 50]).sum;
    [source, resynth];
}.play
)

// trigger the holder to hear the reconstruction on the right hand side
x.set(\t_hold, 1)