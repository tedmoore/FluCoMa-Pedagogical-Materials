s.boot;

// 0. initialize some stuff we need
(
// for holding our frequency modulation parameters (carrier freq, modulating freq, index)
~paramsbuf = Buffer.loadCollection(s,[400,300,3]);

// make sure it's the correct number of samples
~featurebuf = Buffer.alloc(s,7); // for holding our feature analyses

~ds_params = FluidDataSet(s);
~ds_feature = FluidDataSet(s);
)

// 1. a synth to play some frequency modulation
(
~synth = {
	arg vol = -15;

	// read the params buf out of the buffer so we can use them in the synth
	var params = FluidBufToKr.kr(~paramsbuf);
	var cfreq = params[0];
	var mfreq = params[1];
	var index = params[2];

	// frequency modulation:
	var msig = SinOsc.ar(mfreq);
	var csig = SinOsc.ar(cfreq * 2.pow(msig * index));

	// feature analysis of the frequency modulation signal
	// var feature = FluidMFCC.kr(csig,~featurebuf.numFrames,startCoeff:1);
	var feature = FluidSpectralShape.kr(csig);

	// write that analysis into featurebuf
	FluidKrToBuf.kr(feature,~featurebuf);

	csig = csig.dup * vol.dbamp;
}.play;
)

// 2. generate 100 random freq mod parameter sets and save that along with the feature analysis of that sound
(
fork{
	500.do{
		arg i;
		var id = "example-%".format(i);
		// get some randomized parameters for our frequency modulation algorithm
		var cfreq = exprand(100.0,1000.0);
		var mfreq = exprand(100.0,min(cfreq,500.0));
		var index = rrand(0.0,5.0);

		~paramsbuf.setn(0,[cfreq,mfreq,index]);// set the params to the buffer so they are read from the server
		0.1.wait; // wait a moment
		~ds_params.addPoint(id,~paramsbuf);
		~ds_feature.addPoint(id,~featurebuf);
		0.1.wait;
		id.postln;
	};

	~ds_params.print;
	~ds_feature.print;
}
)

// 3. standardize the datasets so they're in generally the same range
(
~feature_scaler = FluidNormalize(s);
// ~feature_scaler = FluidStandardize(s);
~params_scaler = FluidNormalize(s);
~ds_feature_scaled = FluidDataSet(s);
~ds_params_scaled = FluidDataSet(s);
~feature_scaler.fitTransform(~ds_feature,~ds_feature_scaled);
~params_scaler.fitTransform(~ds_params,~ds_params_scaled);
~ds_feature_scaled.print;
~ds_params_scaled.print;
)

// 4. train a neural network to predict synthesis values from the feature analyses
~nn = FluidMLPRegressor(s,[9,5],FluidMLPRegressor.sigmoid,FluidMLPRegressor.sigmoid,maxIter:100,learnRate:0.1,batchSize:2,validation:0);

(
~continuous_train = true;
~train = {
	~nn.fit(~ds_feature_scaled,~ds_params_scaled,{
		arg loss;
		loss.postln;
		if(~continuous_train,{
			~train.();
		});
	})
};
~train.();
)

// tweak parameters
~nn.hiddenLayers_([6,4]);
~nn.learnRate_(0.01);
~nn.batchSize_(1);

~continuous_train = false;

// 4. use this trained neural network to predict FM synth params
(
fork{
	// choose a test sound:
	// var test_buf = Buffer.read(s,FluidFilesPath("Nicol-LoopE-M.wav"));
	var test_buf = Buffer.read(s,FluidFilesPath("Harker-DS-TenOboeMultiphonics-M.wav"));
	// var test_buf = Buffer.read(s,FluidFilesPath("Tremblay-AaS-VoiceQC-B2K-M.wav"));
	// var test_buf = Buffer.read(s,FluidFilesPath("Tremblay-CEL-GlitchyMusicBoxMelo.wav"));
	// var test_buf = Buffer.read(s,FluidFilesPath("Olencki-TenTromboneLongTones-M.wav"));
	// var test_buf = Buffer.read(s,FluidFilesPath("Tremblay-ASWINE-ScratchySynth-M.wav"));

	s.sync;
	{
		arg vol = 0;
		var src = PlayBuf.ar(1,test_buf,BufRateScale.ir(test_buf),loop:1);

		// var feature = FluidMFCC.kr(src,~featurebuf.numFrames,startCoeff:1);
		var feature = FluidSpectralShape.kr(src);

		var vol_handle = FluidLoudness.kr(src)[0];
		var featurebuf_l = LocalBuf(feature.numChannels);
		var featurebuf_scaled_l = LocalBuf(feature.numChannels);
		var paramsbuf_scaled_l = LocalBuf(3);
		var paramsbuf_l = LocalBuf(3);
		var params, cfreq, mfreq, index, msig, csig;
		var trig = Impulse.kr(30);

		FluidKrToBuf.kr(feature,featurebuf_l);
		~feature_scaler.kr(trig,featurebuf_l,featurebuf_scaled_l);
		~nn.kr(trig,featurebuf_scaled_l,paramsbuf_scaled_l);
		~params_scaler.kr(trig,paramsbuf_scaled_l,paramsbuf_l,invert:1);

		params = FluidBufToKr.kr(paramsbuf_l).poll;
		cfreq = params[0];
		mfreq = params[1];
		index = params[2];

		// frequency modulation:
		msig = SinOsc.ar(mfreq);
		csig = SinOsc.ar(cfreq * 2.pow(msig * index));

		[src * -4.dbamp,csig * vol.dbamp * vol_handle.dbamp];
	}.play;
}
)
