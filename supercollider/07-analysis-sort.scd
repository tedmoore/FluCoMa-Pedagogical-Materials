(
~buf = Buffer.read(s,FluidFilesPath("Nicol-LoopE-M.wav"));
~slicepoints = Buffer(s);
~features_buf = Buffer(s); // a buffer for storing the spectral analyses
~stats_buf = Buffer(s); // a buffer for storing the statistics
~mean_centroids = Buffer(s); // a buffer for storing the mean spectral centroids
)


FluidBufAmpSlice.processBlocking(s,~buf,indices:~slicepoints,fastRampUp:10,fastRampDown:2205,slowRampUp:4410,slowRampDown:4410,onThreshold:10,offThreshold:5,floor:-40,minSliceLength:4410,highPassFreq:20,action:{"done".postln;});

FluidWaveform(~buf,~slicepoints,bounds:Rect(0,0,1600,400));

(
~slicepoints.loadToFloatArray(action:{
	arg slicepoints_fa;

	slicepoints_fa.doAdjacentPairs{
		arg startFrame, endFrame, slice_i;
		var num_frames = endFrame - startFrame;
		FluidBufSpectralShape.processBlocking(s,~buf,startFrame,num_frames,features:~features_buf,select:[\centroid]); // spectral analysis
		FluidBufStats.processBlocking(s,~features_buf,stats:~stats_buf,select:[\mean]); // statistical analysis
		FluidBufCompose.processBlocking(s,~stats_buf,destination:~mean_centroids,destStartFrame:slice_i);
	};
});
)

(
~mean_centroids.loadToFloatArray(action:{
	arg fa;
	~order = fa.order;
});
)

~order.postln;

(
fork{
	~order.do{
		arg index;
		index.postln;
		{
			var startPos = Index.kr(~slicepoints,index);
			var endPos = Index.kr(~slicepoints,index + 1);
			var dur_secs = (endPos - startPos) / BufSampleRate.ir(~buf);
			var env = EnvGen.kr(Env([0,1,1,0],[0.03,dur_secs-0.06,0.03]),doneAction:2);
			var sig = PlayBuf.ar(1,~buf,BufRateScale.ir(~buf),startPos:startPos);
			sig.dup * env;
		}.play;

		1.5.wait;
	};
}
)