(
~thisFolder = thisProcess.nowExecutingPath.dirname;

~audio_file_path = FluidFilesPath("Nicol-LoopE-M.wav");
~n_components = 3;
~duration_samples = -1;

/*~audio_file_path = FluidFilesPath("Tremblay-BaB-SoundscapeGolcarWithDog.wav");
~n_components = 2;*/

fork{
	b = Buffer.read(s,~audio_file_path,numFrames:~duration_samples);
	~bases = Buffer(s);
	~acts = Buffer(s);
	~resynth = Buffer(s);
	s.sync;

	// sum to mono
	if(b.numChannels > 1){
		~src = Buffer(s);
		2.do{
			arg i;
			FluidBufCompose.processBlocking(s,b,startChan:i,numChans:1,gain:0.5,destGain:1,destination:~src);
		};

		s.sync;
	}{
		~src = b;
	};

	FluidBufNMF.processBlocking(s,~src,bases:~bases,resynth:~resynth,resynthMode:1,activations:~acts,components:~n_components);
	~mags = Buffer(s);
	FluidBufSTFT.processBlocking(s,~src,magnitude:~mags);

	~tmpBuf = Buffer(s);
	~n_components.do{
		arg i;
		FluidBufCompose.processBlocking(s,~resynth,startChan:i,numChans:1,destination:~tmpBuf);
		s.sync;
		~tmpBuf.write(~thisFolder+/+"flucoma-component-%.wav".format(i),"wav");
		s.sync;
	};
	"done".postln;
}
)

(
~win = Window();
~win.layout = VLayout(
	FluidWaveform(imageBuffer:~mags,parent:~win,standalone:false,imageColorScheme:1,imageColorScaling:1),
	FluidWaveform(featuresBuffer:~bases,parent:~win,standalone:false,normalizeFeaturesIndependently:false),
	FluidWaveform(featuresBuffer:~acts,parent:~win,standalone:false,normalizeFeaturesIndependently:false)
);
~win.front;
)