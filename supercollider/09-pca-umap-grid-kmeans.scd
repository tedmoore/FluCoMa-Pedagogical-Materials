s.boot;

// 1. Load a folder of sounds
(
~folder_path = FluidFilesPath();
~loader = FluidLoadFolder(~folder_path);
~loader.play(s,{
	"loaded % soundfiles".format(~loader.index.size).postln;
})
)

// 2. Slice
(
~indices = Buffer(s);
FluidBufNoveltySlice.processBlocking(s,~loader.buffer,indices:~indices,threshold:0.5,action:{
	"% slices found".format(~indices.numFrames).postln;
	"average duration in seconds: %".format(~loader.buffer.duration/~indices.numFrames).postln;
});
)

// 3. Analyze
(
fork{
	var feature_buf = Buffer(s);
	var stats_buf = Buffer(s);
	var point_buf = Buffer(s);
	~ds = FluidDataSet(s);
	~indices.loadToFloatArray(action:{
		arg fa;
		fa.doAdjacentPairs{
			arg start, end, i;
			var num = end - start;

			// === PICK YOUR ANALYSIS (JUST CHOOSE 1) ===
			FluidBufMFCC.processBlocking(s,~loader.buffer,start,num,features:feature_buf,numCoeffs:13,startCoeff:1,numChans:1);
			// FluidBufChroma.processBlocking(s,~loader.buffer,start,num,features:feature_buf,numChans:1);
			// FluidBufSpectralShape.processBlocking(s,buffer,start,num,features:feature_buf,numChans:1);
			//FluidBufPitch.processBlocking(s,buffer,start,num,features:feature_buf,numChans:1);

			FluidBufStats.processBlocking(s,feature_buf,stats:stats_buf);
			FluidBufFlatten.processBlocking(s,stats_buf,numFrames:1,destination:point_buf);

			~ds.addPoint("slice-%".format(i),point_buf);
			if(i % 100 == 1,{s.sync});
			"% / % done".format(i+1,~indices.numFrames-1).postln;
		};

		~ds.print;
	});
};
)

// 4. Reduce to 2 Dimensions
(
~ds_redux = FluidDataSet(s);
~ds_stand = FluidDataSet(s);

FluidStandardize(s).fitTransform(~ds,~ds_stand);

// perform dim redux
// FluidPCA(s,2).fitTransform(~ds_stand,~ds_redux,{"pca complete".postln}); // try pca first then switch line is commented and try umap
FluidUMAP(s,2).fitTransform(~ds_stand,~ds_redux,{"umap complete".postln});
)

// 5. make a function for handling all the plotting and kdtree stuff
(
~plot = {
	arg ds, action;
	var kdtree = FluidKDTree(s);
	var buf_2d = Buffer.alloc(s,2);
	var scaler = FluidNormalize(s);
	var ds_norm = FluidDataSet(s);

	// whatever the output of umap is, scale it to be between 0 and 1 so that it will look nice in the plotter
	FluidNormalize(s).fitTransform(ds,ds_norm);

	kdtree.fit(ds_norm);
	ds_norm.dump({
		arg dict;
		var previous, fp;
		fork({
			~fp = FluidPlotter(bounds:Rect(0,0,800,800),dict:dict,mouseMoveAction:{
				arg view, x, y;
				buf_2d.setn(0,[x,y]); // load it into a buffer so that...
				kdtree.kNearest(buf_2d,1,{ // it can be passed to the kdtree to find hte nearest neighbour, which is reported back...
					arg nearest; // here
					nearest.postln;
					if(previous != nearest,{ // only if it is a "new" nearest neighbour, should it make sound
						var index = nearest.asString.split($-)[1].asInteger; // peel off the index of the slice
						previous = nearest;
						nearest.postln;
						"nearest point is: %".format(nearest).postln;
						view.highlight_(nearest);
						{
							var startPos = Index.kr(~indices,index); // look up the start position
							var dur_samps = Index.kr(~indices,index + 1) - startPos; // calculate the duration in samples

							// play the buffer starting from the start position
							var sig = PlayBuf.ar(2,~loader.buffer,BufRateScale.ir(~loader.buffer),startPos:startPos)[0];
							var dur_sec = min(dur_samps / BufSampleRate.ir(~loader.buffer),1);
							var env = EnvGen.kr(Env([0,1,1,0],[0.03,dur_sec-0.06,0.03]),doneAction:2);
							sig.dup * env;
						}.play;
					});
				});
			});
			action.value;
		},AppClock);
	});
};
)

// 6. and plot!
~plot.(~ds_redux);

// 7. grid
(
~ds_grid = FluidDataSet(s);
FluidGrid(s).fitTransform(~ds_redux,~ds_grid);
~plot.(~ds_grid);
)

// 8. kmeans on the dim redux dataset
(
var labels = FluidLabelSet(s);
FluidKMeans(s,4).fitPredict(~ds_redux,labels); // try with a different number of clusters
~plot.(~ds_redux,{
	labels.dump{
		arg labelsdict;
		~fp.categories_(labelsdict);
	}
});
)
