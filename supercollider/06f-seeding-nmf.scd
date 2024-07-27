s.options.sampleRate = 44100;
s.options.device = "Fireface UC Mac (24006457)";

// the buffer to decompose
(
fork{
	~drums = Buffer.read(s,FluidFilesPath("Nicol-LoopE-M.wav"));
	s.sync;
	defer{ FluidWaveform(~drums) }
}
)

// make the sythetic bases for seeding
(
fork{
	~bases = Buffer.loadCollection(s,513.collect{
		arg i;
		var kick = 0;
		var snare = 0;
		var hh = i.linlin(0,512,0.0,pi).sin;

		if(i < 10,{kick = 1});

		if((i > 10) && (i < 100),{snare = 1});

		[kick,snare,hh];
	}.flatten,3);

	s.sync;

	defer{ FluidWaveform(featuresBuffer:~bases,stackFeatures:true) }
}
)

// decompose with seeded synthetic bases (basesMode = 1)
(
fork{
	~activations = Buffer(s);
	~resynth = Buffer(s);
	~n_components = 3;
	FluidBufNMF.processBlocking(s,~drums,activations:~activations,bases:~bases,basesMode:1,resynthMode:1,resynth:~resynth,components:~n_components);
	s.sync;
	defer{
		w = Window();
		w.layout = VLayout(
			FluidWaveform(~resynth,featuresBuffer:~activations,stackFeatures:true,normalizeFeaturesIndependently:false),
			FluidWaveform(featuresBuffer:~bases,stackFeatures:true,normalizeFeaturesIndependently:false)
		);
		w.front;
	}
}
)

// ***** deriving bases (for seeding) from analysis *****

// we want to decompose this melody into components of individual notes
~piano = Buffer.read(s,thisProcess.nowExecutingPath.dirname+/+"06f-somewhere-over-the-rainbow-2.wav");
~piano.play;

// start with an audio recording of the notes that we know will be present
~saw_scale = Buffer.read(s,thisProcess.nowExecutingPath.dirname+/+"06f_saw_scale.wav");
~saw_scale.play;

// decompose scale to get the bases of the different notes
(
fork{
	~bases = Buffer(s);
	~activations = Buffer(s);
	~resynth = Buffer(s);
	FluidBufNMF.processBlocking(s,~saw_scale,bases:~bases,activations:~activations,components:8,resynth:~resynth,resynthMode:1);
	s.sync;

	// see it:
	defer{
		w = Window();
		w.layout = VLayout(
			FluidWaveform(~resynth,featuresBuffer:~activations,stackFeatures:true,normalizeFeaturesIndependently:false),
			FluidWaveform(featuresBuffer:~bases,stackFeatures:true)
		);
		w.front;
	};

	1.wait;

	// hear it:
	~resynth.numChannels.do{
		arg i;
		{
			var sig = PlayBuf.ar(~resynth.numChannels,~resynth,BufRateScale.ir(~resynth),doneAction:2);
			sig[i].dup;
		}.play;

		~resynth.duration.wait;
	};
}
)

// seed with the bases of the different pitches to *find* these pitches in the melody (basesMode = 2)
(
fork{
	FluidBufNMF.processBlocking(s,~piano,resynth:~resynth,resynthMode:1,bases:~bases,activations:~activations,basesMode:2,components:~bases.numChannels);
	s.sync;
	defer{ FluidWaveform(~resynth,featuresBuffer:~activations,stackFeatures:true,normalizeFeaturesIndependently:false) };

	1.wait;

	~resynth.numChannels.do{
		arg i;
		{
			var sig = PlayBuf.ar(~resynth.numChannels,~resynth,BufRateScale.ir(~resynth),doneAction:2);
			sig[i].dup;
		}.play;

		~resynth.duration.wait;
	};
}
)

// but the notes are in the wrong order, how can I programmatically sort the notes?
// (could do a pitch analysis and sort that way...)
// or organize the bases ahead of time

// here's a buffer of synthetic activations to seed the scale with... so we can indicate *where* the different notes are and
// get them returned to us in *order*
(
fork{
	~hopSize = 512;
	~activations = Buffer.alloc(s,(~saw_scale.numFrames / ~hopSize) + 1,8);
	s.sync;
	~buffer_of_ones = Buffer.loadCollection(s,Array.fill((~activations.numFrames / 8).floor,{1}));
	s.sync;
	8.do{
		arg i;
		FluidBufCompose.processBlocking(s,~buffer_of_ones,destination:~activations,destStartFrame:i * ~buffer_of_ones.numFrames,destStartChan:i);
	};

	s.sync;

	defer{ FluidWaveform(featuresBuffer:~activations,stackFeatures:true) }
}
)

// decompose the scale *again*, but this time seeding the activations and specifying actMode = 1
(
fork{
	FluidBufNMF.processBlocking(s,~saw_scale,bases:~bases,activations:~activations,components:8,actMode:1,resynth:~resynth,resynthMode:1);
	s.sync;
	defer{
		w = Window();
		w.layout = VLayout(
			FluidWaveform(~resynth,featuresBuffer:~activations,stackFeatures:true),
			FluidWaveform(featuresBuffer:~bases,stackFeatures:true)
		);
		w.front;
	}
}
)

// now that the *bases* are in the sorted order, decompose the melody again with these *ordered* bases as tehe seed (basesMode = 2)
(
fork{
	FluidBufNMF.processBlocking(s,~piano,resynth:~resynth,resynthMode:1,bases:~bases,basesMode:2,activations:~activations,components:~bases.numChannels);
	s.sync;
	defer{ FluidWaveform(~resynth,featuresBuffer:~activations,stackFeatures:true,normalizeFeaturesIndependently:false) };

	1.wait;

	~resynth.numChannels.do{
		arg i;
		{
			var sig = PlayBuf.ar(~resynth.numChannels,~resynth,BufRateScale.ir(~resynth),doneAction:2);
			sig[i].dup;
		}.play;

		~resynth.duration.wait;
	};
}
)

// transcribe
(
fork{
	~transcription_buffer = Buffer.alloc(s,~piano.numFrames);
	~resynth_channels = ~resynth.numChannels.collect{
		arg i;
		var buf = Buffer(s);
		FluidBufCompose.process(s,~resynth,startChan:i,numChans:1,destination:buf);
		buf;
	};
	~midis = [0,2,4,5,7,9,11,12] + 60;
	~indices = { Buffer(s) } ! ~activations.numChannels;
	s.sync;
	~activations.numChannels.do{
		arg i;

		FluidBufOnsetSlice.processBlocking(
			server:s,
			source: ~resynth,
			startChan:i,
			numChans:1,
			indices:~indices[i],
			metric:0,
			threshold:0.15,
			minSliceLength:20
		);

		~indices[i].loadToFloatArray(action:{
			arg fa;
			"scale degree % (midi note %, %) onsets: %".format(i,~midis[i],~midis[i].midiname,fa).postln;
			fa.do{
				arg index;
				if( index > 0 ){
					~transcription_buffer.set(index,~midis[i]);
				};
			};
		});
	};

	s.sync;

	defer{
		w = Window();
		w.layout = VLayout(*~indices.collect{
			arg ind, i;
			FluidWaveform(~resynth_channels[i],ind);
		});
		w.front;
	}
}
)

// hear the transcription
(
{
	var note = PlayBuf.ar(1,~transcription_buffer,BufRateScale.ir(~transcription_buffer),doneAction:2);
	var gate = Trig1.kr(Changed.ar(note),0.1);
	var sig;
	note = Latch.kr(note,gate);
	sig = LFTri.ar(note.midicps) * gate.lag(0.03) * -20.dbamp;
	sig.dup;
}.play;
)