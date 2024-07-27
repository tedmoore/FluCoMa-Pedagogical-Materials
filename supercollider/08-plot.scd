~buf = Buffer.read(s,FluidFilesPath("Nicol-LoopE-M.wav"));

(
~slicepoints = Buffer(s);
FluidBufAmpSlice.processBlocking(s,~buf,indices:~slicepoints,fastRampUp:10,fastRampDown:2205,slowRampUp:4410,slowRampDown:4410,onThreshold:10,offThreshold:5,floor:-40,minSliceLength:4410,highPassFreq:20,action:{"done".postln;});
)

FluidWaveform(~buf,~slicepoints,bounds:Rect(0,0,1600,400));

(
~features_buf = Buffer(s);
~stats_buf = Buffer(s);
~point_buf = Buffer(s,2); // for putting our 2D data point in
~ds = FluidDataSet(s); // for storing our 2D data points
~slicepoints.loadToFloatArray(action:{
	arg slicepoints_fa;
	slicepoints_fa.doAdjacentPairs{
		arg startFrame, endFrame, slice_i;
		var num_frames = endFrame - startFrame;

		"analyzing slice: %".format(slice_i).postln;

		FluidBufSpectralShape.processBlocking(s,~buf,startFrame,num_frames,features:~features_buf,select:[\centroid]); // spectral analysis
		FluidBufStats.processBlocking(s,~features_buf,select:[\mean],stats:~stats_buf); // statistical analysis
		FluidBufCompose.processBlocking(s,~stats_buf,destination:~point_buf,destStartFrame:0); // write mean centroid into point_buf

		FluidBufLoudness.processBlocking(s,~buf,startFrame,num_frames,features:~features_buf,select:[\loudness]); // loudness analysis
		FluidBufStats.processBlocking(s,~features_buf,select:[\mean],stats:~stats_buf); // statistical analysis
		FluidBufCompose.processBlocking(s,~stats_buf,destination:~point_buf,destStartFrame:1); // write mean loudness into point_buf

		~ds.addPoint(slice_i,~point_buf); // save point_buf to the dataset

		s.sync;
	};

	"analysis done".postln;
});
)

(
~ds_scaled = FluidDataSet(s);
~scaler = FluidNormalize(s).fitTransform(~ds,~ds_scaled); // scales all points to have values between 0 and 1
~kdtree = FluidKDTree(s).fit(~ds_scaled);
~xybuf = Buffer.alloc(s,2);
~ds_scaled.dump({ // load the dataset to the language as a dictionary
	arg ds_dict;
	var prev = nil;
	{
		FluidPlotter(bounds:Rect(0,0,800,800),dict:ds_dict,mouseMoveAction:{ // pass that dictionary to the plotter for looking at
			arg view, x, y, modifiers; // click and drag on the plotter to see where your mouse is
			~xybuf.setn(0,[x,y]);
			~kdtree.kNearest(~xybuf,1,{
				arg nearest;
				if(nearest != prev){
					nearest.postln;
					view.highlight_(nearest);

					{
						var startPos = Index.kr(~slicepoints,nearest.asInteger);
						var endPos = Index.kr(~slicepoints,nearest.asInteger + 1);
						var dur_secs = (endPos - startPos) / BufSampleRate.ir(~buf);
						var env = EnvGen.kr(Env([0,1,1,0],[0.03,dur_secs-0.06,0.03]),doneAction:2);
						var sig = PlayBuf.ar(1,~buf,BufRateScale.ir(~buf),startPos:startPos);
						sig.dup * env;
					}.play;

					prev = nearest;
				}
			});
		})
	}.defer;
});
)