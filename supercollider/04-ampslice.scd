// audio rate version

~buf = Buffer.read(s,FluidFilesPath("Nicol-LoopE-M.wav"));

~buf.play;

(
{
	var sig = PlayBuf.ar(1,~buf,BufRateScale.kr(~buf));
	var onsets = FluidAmpSlice.ar(sig,
		fastRampUp:10,
		fastRampDown:2205,
		slowRampUp:4410,
		slowRampDown:4410,
		onThreshold:10,
		offThreshold:5,
		floor:-40,
		minSliceLength:4410,
		highPassFreq:20
	);
	[sig,onsets];
}.play;
)

// buffer version

(
fork({

	var buf = Buffer.read(s,FluidFilesPath("Nicol-LoopE-M.wav"));
	var slicepoints = Buffer(s);

	s.sync;

	FluidBufAmpSlice.processBlocking(s,buf,indices:slicepoints,fastRampUp:10,fastRampDown:2205,slowRampUp:4410,slowRampDown:4410,onThreshold:10,offThreshold:5,floor:-40,minSliceLength:4410,highPassFreq:20);

	s.sync;

	slicepoints.loadToFloatArray(action:{
		arg fa;
		fa.postln;
	});

	FluidWaveform(buf,slicepoints);
},AppClock);
)

// FluidAmpFeature as an audio FX

~drums = Buffer.read(s,FluidFilesPath("Nicol-LoopE-M.wav"));

// listen to the original
~drums.play;

// add extra pop to the drums by using the AmpFeature envelope
(
{
    var sig = PlayBuf.ar(~drums.numChannels,~drums,BufRateScale.ir(~drums),loop:1);
    var amp_feature = FluidAmpFeature.ar(sig,100,100,44100,44100,-40);
    amp_feature.poll;
    sig = sig * amp_feature.dbamp * -30.dbamp;
	sig.dup;
}.play;
)

// really suppress the amplitude peaks by inverting the feature
(
{
    var sig = PlayBuf.ar(~drums.numChannels,~drums,BufRateScale.ir(~drums),loop:1);
    var amp_feature = FluidAmpFeature.ar(sig,100,100,44100,44100,-40) * -1;
    amp_feature.poll;
    sig = sig * amp_feature.dbamp;
	sig.dup;
}.play;
)