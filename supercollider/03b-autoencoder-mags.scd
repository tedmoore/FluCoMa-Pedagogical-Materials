s.options.device_("Sonarworks Systemwide");
s.options.numWireBufs_(2048);

// initialize some buffers
(
~path = FluidFilesPath("Olencki-TenTromboneLongTones-M.wav");
// ~path = FluidFilesPath("Tremblay-AaS-VoiceQC-B2K-M.wav");
// ~path = "/Users/ted/Desktop/1-min-nim-constellation.wav";
// ~path = "/Users/ted/Desktop/rotated_summed_in_time_domain.wav";
Window.closeAll;
~buf = Buffer.read(s,~path);
~indices = Buffer(s);
~concat_buf = Buffer(s);
~fftSize = 2048;
)

// remove the silent parts of the buffer
(
FluidBufAmpGate.processBlocking(s,~buf,indices:~indices,onThreshold:-30,offThreshold:-40,minSliceLength:0.1*s.sampleRate,minSilenceLength:0.1*s.sampleRate,rampDown:0.01*s.sampleRate);
~indices.loadToFloatArray(action:{
	arg fa;
	var current_frame = 0;

	// this array is initally flat, but is alternating [ onset0 , offset0 , onset1 , offset1 , onset2 ... ],
	// so by using .clump(2) we clump each onset and offest together to get an array like this:
	// [ [ onset0 , offset0 ] , [ onset1 , offset1 ] , [ onset2 , offset2 ] , ... ]
	fa = fa.clump(2);

	fa.size.postln;
	fa.do{
		arg arr, i;
		var startFrame = arr[0];
		var numFrames = arr[1] - startFrame;
		"%\tstart: %\tend: %".format(i,startFrame,numFrames).postln;
		FluidBufCompose.processBlocking(s,~buf,startFrame,numFrames,destination:~concat_buf,destStartFrame:current_frame);
		current_frame = current_frame + numFrames;
	};

	s.sync;

	defer{FluidWaveform(~concat_buf)};
});
)

// or don't
~concat_buf = ~buf;

// make a dataset comprised of points that fft frames
(
fork{
	~magsbuf = Buffer(s);
	~ds = FluidDataSet(s);
	FluidBufSTFT.processBlocking(s,~concat_buf,magnitude:~magsbuf,windowSize:2048);
	~ds.fromBuffer(~magsbuf);
	s.sync;
	~ds.print;
	"done".postln;
}
)

// use PCA to reduce the number of dimensions from 2048 to something smaller
(
~ds_pca = FluidDataSet(s);
~pca = FluidPCA(s,20);
~pca.fitTransform(~ds,~ds_pca,{
	arg variance;
	variance.postln;
});
)

// take a look at it
~ds_pca.print;

// scale
(
~scaler = FluidNormalize(s);
~ds_scaled = FluidDataSet(s);
~scaler.fitTransform(~ds_pca,~ds_scaled);
~ds_scaled.print;
)

// train the autoencoder
(
// ~nn_shape = [200,100,50,2].mirror;
~nn_shape = [15,10,5,2].mirror;
~ae = FluidMLPRegressor(s,~nn_shape,FluidMLPRegressor.relu,FluidMLPRegressor.sigmoid,learnRate:0.1,maxIter:1,validation:0.2);
// ~ae.tapOut_(-1);
~continuous = true;
~train = {
	~ae.fit(~ds_scaled,~ds_scaled,{
		arg loss;
		loss.postln;
		if(~continuous,{~train.()});
	});
};
~train.();
)

// tweak the learning rate
~ae.learnRate_(0.01);
~ae.batchSize_(5);
~ae.maxIter_(50);
~ae.validation_(0.2);

// turn off continuous training
~continuous = false;

// plot it!
(
~ds_predict = FluidDataSet(s);
~ae.tapIn_(0).tapOut_((~nn_shape.size+1)/2);
~ae.predict(~ds_scaled,~ds_predict,{"prediction done".postln;});
~ds_predict.print;
~ds_predict_norm = FluidDataSet(s);
~norm2D = FluidNormalize(s).fitTransform(~ds_predict,~ds_predict_norm);
~buf2D_norm = Buffer.alloc(s,2);
~buf2D = Buffer.alloc(s,2);
~buf_pca_point = Buffer.alloc(s,~pca.numDimensions);
~buf_pca_point_norm = Buffer.alloc(s,~pca.numDimensions);
~buf_scaler = Buffer.alloc(s,~pca.numDimensions);
~buf_original = Buffer.alloc(s,(~fftSize / 2) + 1);
~wave = Buffer.alloc(s,(~fftSize / 2) + 1);
~ae.tapIn_((~nn_shape.size+1)/2);
~ae.tapOut_(-1);
~display_to_ms = {
	arg vec, ms;
	vec = vec[0..(vec.size/4).asInteger];
	defer{ms.value_(vec / vec.maxItem)};
};

~kdtree = FluidKDTree(s).fit(~ds_predict_norm);

~ds_predict_norm.dump({
	arg dict;
	fork({
		var win = Window("Autoencoder Mags",Rect(0,0,1024,750));
		var ms = 2.collect{arg i; MultiSliderView(win,Rect(i * 512,600,512,100)) };
		ms.do(_.elasticMode_(true));
		ms.do(_.reference_(0.5));
		ms.do(_.drawRects = false);
		ms.do(_.drawLines = true);

		StaticText(win,Rect(0,700,512,20)).string_("Original at Nearest Neighbor");
		StaticText(win,Rect(512,700,512,20)).string_("Predicted Magnitudes");

		~fftbuf = Buffer.alloc(s,~fftSize);

		s.sync;

		{
			var sig;
			var chain;
			chain = PV_Copy(~fftbuf,LocalBuf(~fftSize));
			chain = FFTTrigger(chain,0.5);
			sig = IFFT(chain);
			sig = Limiter.ar(sig);
			sig.dup;
		}.play;

		~prev = 0;
		FluidPlotter(win,bounds:Rect((win.bounds.width-600) / 2,0,600,600),dict:dict,mouseMoveAction:{
			arg view, x, y, mod, butnum, clickcount;
			// [view, x, y, mod, butnum, clickcount].postln;
			if(butnum.isNil || (clickcount == 1)){

				// display preciction
				~buf2D_norm.setn(0,[x,y]);
				~norm2D.inverseTransformPoint(~buf2D_norm,~buf2D);
				~ae.predictPoint(~buf2D,~buf_pca_point);
				~scaler.inverseTransformPoint(~buf_pca_point,~buf_scaler);
				~pca.inverseTransformPoint(~buf_scaler,~wave);
				~wave.loadToFloatArray(action:{
					arg fa;
					// fa.size.postln;
					if(fa.size > 0){
						var fftvec = fa[0..(fa.size-1)].collect{
							arg mag;
							var phs = rrand(0,2pi);
							var real = mag * cos(phs);
							var img = mag * sin(phs);
							[real,img]
						}.flat;

						~fftbuf.setn(0,[0,0] ++ fftvec);
						~display_to_ms.(fa,ms[1]);

						~kdtree.kNearest(~buf2D_norm,1,{
							arg id;
							view.highlight_(id);
							fork{
								~ds.getPoint(id,~buf_original);
								~buf_original.loadToFloatArray(action:{
									arg fa;
									if(fa.size > 0){ ~display_to_ms.(fa,ms[0]) };
								});
							}
						});
					};
				});
			}
		});

		win.front;
	},AppClock);
});
)

(
p = Plotter();
fork{
	inf.do{

		~fftbuf[0].loadToFloatArray(action:{
			arg fa;
			defer{
				p.value_(fa)
			}
		});
		0.03.wait;
	}
};
)
FreqScope()