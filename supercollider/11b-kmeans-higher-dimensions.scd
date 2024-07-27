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

// 4. scaling is probably a good idea
(
~ds_stand = FluidDataSet(s);
FluidStandardize(s).fitTransform(~ds,~ds_stand);
)

// 5. kmeans in the 13 dimensional space
(
~numClusters = 8;
~labels = FluidLabelSet(s);
~kmeans = FluidKMeans(s,~numClusters).fitPredict(~ds_stand,~labels,{"kmeans done".postln}); // try different number of clusters...
)

// 6. get out clusters
(
~clusters = Array.fill(~numClusters,{List.new});
~labels.dump{
	arg labelsdict;
	labelsdict["data"].keysValuesDo{
		arg id, cluster;
		~clusters[cluster[0].asInteger].add(id);
	};
	~clusters.do{
		arg cl, i;
		"cluster ".post; i.postln;
		"has % points".format(cl.size).postln;
		cl.postln;
		"".postln;
	};
};
)

// 7. a helpful function for playing a slice from it's identifier
(
~play_id = {
	arg id;
	var index = id.asString.split($-)[1].asInteger; // peel off the index of the slice
	{
		var startPos = Index.kr(~indices,index); // look up the start position
		var dur_samps = Index.kr(~indices,index + 1) - startPos; // calculate the duration in samples

		// play the buffer starting from the start position
		var sig = PlayBuf.ar(2,~loader.buffer,BufRateScale.ir(~loader.buffer),startPos:startPos)[0];
		var dur_sec = min(dur_samps / BufSampleRate.ir(~loader.buffer),1);
		var env = EnvGen.kr(Env([0,1,1,0],[0.03,dur_sec-0.06,0.03]),doneAction:2);
		sig.dup * env;
	}.play;
};
)

// 7. play a cluster
(
fork{
	~clusters[0].do{
		arg id;
		id.postln;
		~play_id.(id);
		1.wait;
	}
}
)

// 8. sort by distance
(
~distances = FluidDataSet(s);
~kmeans.transform(~ds_stand,~distances);
~distances.dump{
	arg dsts;

	~clusters_by_dist = Array.fill(~numClusters,{List.new});

	dsts["data"].keysValuesDo{
		arg id, distances;
		var cluster = distances.minIndex;
		var dist = distances[cluster];
		~clusters_by_dist[cluster].add((id:id,distance:dist));
	};

	~clusters_by_dist.collect{
		arg clusterArray;
		clusterArray.sort({
			arg a, b;
			a.distance < b.distance;
		});
	};
};
)

// peek
~clusters_by_dist.postln;

// 9. play a cluster sorted by distance
(
fork{
	~clusters_by_dist[3].do{
		arg ev;
		"%:\t%".format(ev.id,ev.distance).postln;
		~play_id.(ev.id);
		0.2.wait;
	};
}
)