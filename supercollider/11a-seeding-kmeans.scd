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
~ds_stand = FluidDataSet(s);
~ds_redux = FluidDataSet(s);
FluidStandardize(s).fitTransform(~ds,~ds_stand);
FluidUMAP(s).fitTransform(~ds_stand,~ds_redux,{"redux complete".postln});
)

// 5. plot it and then click on the plot in the places you want to seed the means. it will post the dataset of means as you make them
(
var buf_2d = Buffer.alloc(s,2);

~ds_norm = FluidDataSet(s);
FluidNormalize(s).fitTransform(~ds_redux,~ds_norm);

~ds_seeds = FluidDataSet(s);

~ds_norm.dump({
	arg dict;
	var previous;
	fork({
		~fp = FluidPlotter(bounds:Rect(0,0,800,800),dict:dict,mouseMoveAction:{
			arg view, x, y, modifiers, buttonnumber, clickcount;
			if(clickcount == 1){
				buf_2d.setn(0,[x,y]);
				~ds_seeds.addPoint(UniqueID.next,buf_2d); // identifier doesn't matter in this case!
				~ds_seeds.print;
			}
		});
	},AppClock);
});
)

// 6. don't close the plotter window and run the kmeans, then go look at the plotter
(
~ds_seeds.size{
	arg sz;
	var labels = FluidLabelSet(s);
	var kmeans = FluidKMeans(s,sz).setMeans(~ds_seeds).fitPredict(~ds_norm,labels);
	labels.dump{
		arg labeldict;
		~fp.categories_(labeldict);
	}
}
)