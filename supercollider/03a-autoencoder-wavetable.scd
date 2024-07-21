// initialize some buffers
(
Window.closeAll;
~buf = Buffer.read(s,FluidFilesPath("Olencki-TenTromboneLongTones-M.wav"));
// ~buf = Buffer.read(s,"/Users/ted/Desktop/1-min-nim-constellation.wav");
// ~buf = Buffer.read(s,FluidFilesPath("Harker-DS-TenOboeMultiphonics-M.wav"));
~indices = Buffer(s);
~concat_buf = Buffer(s);
~winSize = 2048;
~bufWin = Buffer.alloc(s,~winSize);
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

// make a dataset comprised of points that are 2048 samples long
(
fork{
	~ds = FluidDataSet(s);
	~currentFrame = ~winSize;
	~counter = 0;
	while({
		~currentFrame < ~concat_buf.numFrames;
	},{
		FluidBufCompose.processBlocking(s,~concat_buf,~currentFrame-~winSize,~winSize,destination:~bufWin);
		~ds.addPoint(~counter,~bufWin);
		~counter.postln;
		"% / %".format(~currentFrame.asString.padLeft(10),~concat_buf.numFrames.asString.padLeft(10)).postln;
		~counter = ~counter + 1;
		~currentFrame = ~currentFrame + ~winSize;
		s.sync;
	});
	"done".postln;
}
)

// take a look at it
~ds.print;

// use PCA to reduce the number of dimensions from 2048 to something smaller
(
~ds_pca = FluidDataSet(s);
~pca = FluidPCA(s,150);
~pca.fitTransform(~ds,~ds_pca,{
	arg variance;
	variance.postln;
});
)

// take a look at it
~ds_pca.print;

// train the autoencoder
(
~nn_shape = [100,80,50,20,2].mirror;
~ae = FluidMLPRegressor(s,~nn_shape,FluidMLPRegressor.relu,FluidMLPRegressor.identity,learnRate:0.1,maxIter:10,validation:0);
~ae.tapOut_(-1);
~continuous = true;
~train = {
	~ae.fit(~ds_pca,~ds_pca,{
		arg loss;
		loss.postln;
		if(~continuous,{~train.()});
	});
};
~train.();
)

// tweak the learning rate
~ae.learnRate_(0.001);
~ae.batchSize_(30);

// turn off continuous training
~continuous = false;


// plot it!
(
~ds_predict = FluidDataSet(s);
~ae.tapIn_(0).tapOut_((~nn_shape.size+1)/2);
~ae.predict(~ds_pca,~ds_predict,{"prediction done".postln;});
~ds_predict.print;
~ds_predict_norm = FluidDataSet(s);
~norm2D = FluidNormalize(s).fitTransform(~ds_predict,~ds_predict_norm);
~buf2D_norm = Buffer.alloc(s,2);
~buf2D = Buffer.alloc(s,2);
~buf_pca_point = Buffer.alloc(s,~pca.numDimensions);
~buf_pca_point_norm = Buffer.alloc(s,~pca.numDimensions);
~wave = Buffer.alloc(s,~winSize);
~ae.tapIn_((~nn_shape.size+1)/2);
~ae.tapOut_(-1);
~ds_predict_norm.dump({
	arg dict;
	fork({
		var win = Window("Autoencoder Wavetable",Rect(0,0,1024,700));
		var ms = MultiSliderView(win,Rect(0,600,1024,100));
		ms.elasticMode_(true);
		ms.reference_(0.5);
		ms.drawRects = false;
		ms.drawLines = true;

		{
			var n = 4;
			var rate = 1;
			var phs = Phasor.ar(0,rate,0,BufFrames.kr(~wave));
			var phss = n.collect{
				arg i;
				var p = phs + ((BufFrames.kr(~wave) / n) * i);
				p % (BufFrames.kr(~wave));
			};
			var sig = BufRd.ar(1,~wave,phss,1,4);
			var env = EnvGen.ar(Env([0,1,0],[SampleDur.ir * ~winSize * 0.5].dup,\sin),phss > 0.5,timeScale:rate.reciprocal);
			sig = sig * env;
			Mix(sig).dup;
		}.play;


		FluidPlotter(win,bounds:Rect((win.bounds.width-600) / 2,0,600,600),dict:dict,mouseMoveAction:{
			arg view, x, y;
			fork{
				~buf2D_norm.setn(0,[x,y]);
				~norm2D.inverseTransformPoint(~buf2D_norm,~buf2D);
				~ae.predictPoint(~buf2D,~buf_pca_point);
				~pca.inverseTransformPoint(~buf_pca_point,~wave);
				~wave.loadToFloatArray(action:{
					arg fa;
					fa.size.postln;
					if(fa.size > 0,{
						defer{ms.value_(fa.linlin(-1,1,0,1))};
					});
				});
			}
		});

		win.front;
	},AppClock);
});
)