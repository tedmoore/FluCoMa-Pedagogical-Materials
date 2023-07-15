// audio rate version

~buf = Buffer.read(s,FluidFilesPath("Nicol-LoopE-M.wav"));

(
{
	var sig = PlayBuf.ar(1,~buf,BufRateScale.kr(~buf),loop:1);
	var onsets = FluidAmpSlice.ar(sig,fastRampUp:10,fastRampDown:2205,slowRampUp:4410,slowRampDown:4410,onThreshold:10,offThreshold:5,floor:-40,minSliceLength:4410,highPassFreq:20);
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

	FluidWaveform(buf,slicepoints);
},AppClock);
)