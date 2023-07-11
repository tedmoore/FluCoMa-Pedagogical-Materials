s.boot;

// 0. initialize some stuff we need
(
// for holding our frequency modulation parameters (carrier freq, modulating freq, index)
~paramsbuf = Buffer.loadCollection(s,[400,300,3]);
~mfccbuf = Buffer.alloc(s,13); // for holding our MFCC analyses
~ds_params = FluidDataSet(s);
~ds_mfcc = FluidDataSet(s);
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
	var msig = SinOsc.ar(mfreq,0,mfreq * index);
	var csig = SinOsc.ar(cfreq + msig);

	// mfcc analysis of the frequency modulation signal
	var mfcc = FluidMFCC.kr(csig,~mfccbuf.numFrames,startCoeff:1);

	// write that analysis into mfccbuf
	FluidKrToBuf.kr(mfcc,~mfccbuf);

	csig = csig.dup * vol.dbamp;
}.play;
)

// 2. generate 100 random freq mod parameter sets and save that along with the MFCC analysis of that sound
(
fork{
	100.do{
		arg i;
		var id = "example-%".format(i);
		// get some randomized parameters for our frequency modulation algorithm
		var cfreq = exprand(100.0,1000.0);
		var mfreq = exprand(100.0,min(cfreq,500.0));
		var index = rrand(0.0,8.0);

		~paramsbuf.setn(0,[cfreq,mfreq,index]);// set the params to the buffer so they are read from the server
		0.1.wait; // wait a moment
		~ds_params.addPoint(id,~paramsbuf);
		~ds_mfcc.addPoint(id,~mfccbuf);
		0.1.wait;
		id.postln;
	};

	~ds_params.print;
	~ds_mfcc.print;
}
)

// 3. standardize the datasets so they're in generally the same range
(
// ~mfcc_scaler = FluidNormalize(s);
~mfcc_scaler = FluidStandardize(s);
~params_scaler = FluidNormalize(s);
~ds_mfcc_scaled = FluidDataSet(s);
~ds_params_scaled = FluidDataSet(s);
~mfcc_scaler.fitTransform(~ds_mfcc,~ds_mfcc_scaled);
~params_scaler.fitTransform(~ds_params,~ds_params_scaled);
~ds_mfcc_scaled.print;
~ds_params_scaled.print;
)

// 4. train a neural network to predict synthesis values from the mfcc analyses
~nn = FluidMLPRegressor(s,[9,5],FluidMLPRegressor.sigmoid,FluidMLPRegressor.sigmoid,maxIter:100,learnRate:0.1,batchSize:2,validation:0);

(
~continuous_train = true;
~train = {
	~nn.fit(~ds_mfcc_scaled,~ds_params_scaled,{
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
~nn.hidden_([9,5]);
~nn.learnRate_(0.01);
~nn.batchSize_(2);

~continuous_train = false;

// 4. use this trained neural network to predict FM synth params
(
fork{
	// choose a test sound:
	// var test_buf = Buffer.read(s,FluidFilesPath("Nicol-LoopE-M.wav"));
	// var test_buf = Buffer.read(s,FluidFilesPath("Harker-DS-TenOboeMultiphonics-M.wav"));
	// var test_buf = Buffer.read(s,FluidFilesPath("Tremblay-AaS-VoiceQC-B2K-M.wav"));
	var test_buf = Buffer.read(s,FluidFilesPath("Tremblay-CEL-GlitchyMusicBoxMelo.wav"));

	s.sync;
	{
		arg vol = 0;
		var src = PlayBuf.ar(1,test_buf,BufRateScale.ir(test_buf),loop:1);
		var mfcc = FluidMFCC.kr(src,~mfccbuf.numFrames,startCoeff:1);
		var vol_handle = FluidLoudness.kr(src)[0];
		var mfccbuf_l = LocalBuf(mfcc.numChannels);
		var mfccbuf_scaled_l = LocalBuf(mfcc.numChannels);
		var paramsbuf_scaled_l = LocalBuf(3);
		var paramsbuf_l = LocalBuf(3);
		var params, cfreq, mfreq, index, msig, csig;
		var trig = Impulse.kr(30);

		FluidKrToBuf.kr(mfcc,mfccbuf_l);
		~mfcc_scaler.kr(trig,mfccbuf_l,mfccbuf_scaled_l);
		~nn.kr(trig,mfccbuf_scaled_l,paramsbuf_scaled_l);
		~params_scaler.kr(trig,paramsbuf_scaled_l,paramsbuf_l,invert:1);

		params = FluidBufToKr.kr(paramsbuf_l).poll;
		cfreq = params[0];
		mfreq = params[1];
		index = params[2];

		// frequency modulation:
		msig = SinOsc.ar(mfreq,0,mfreq * index);
		csig = SinOsc.ar(cfreq + msig);

		[src * -4.dbamp,csig * vol.dbamp * vol_handle.dbamp];
	}.play;
}
)
