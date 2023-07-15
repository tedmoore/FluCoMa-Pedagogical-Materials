/*
=================================================
|                                               |
|       LOAD AND ANALYZE THE SOURCE MATERIAL    |
|                                               |
=================================================
*/

(
// ============= 1. LOAD SOME FILES TO BE THE SOURCE MATERIAL ===================
// put your own folder path here! it's best if they're all mono for now.
~source_files_folder = "/Users/ted/Documents/_flucoma/01-FluCoMa-CCRMA/favs mono/";

~loader = FluidLoadFolder(~source_files_folder); // this is a nice helper class that will load a bunch of files from a folder.
~loader.play(s,{ // .play will cause it to *actually* do the loading

	// we really just want access to the buffer. there is also a .index with some info about the files
	// but we'll igore that for now
	~source_buf = ~loader.buffer;

	"all files loaded".postln;

	// double check if they're all mono? the buffer of the loaded files will have as many channels as the file with the most channels
	// so if this is 1, then we know all the files were mono.
	"num channels: %".format(~source_buf.numChannels).postln
});
)

(
// ==================== 2. SLICE THE SOURCE MATERIAL ACCORDING TO SPECTRAL ONSETS =========================
~source_indices_buf = Buffer(s); // a buffer for writing the indices into
FluidBufOnsetSlice.processBlocking(s,~source_buf,indices:~source_indices_buf,metric:9,threshold:0.5,minSliceLength:9,action:{ // do the slicing
	~source_indices_buf.loadToFloatArray(action:{
		arg indices_array;

		// post the results so that you can tweak the parameters and get what you want
		"found % slices".format(indices_array.size-1).postln;
		"average length: % seconds".format((~source_buf.duration / (indices_array.size-1)).round(0.001)).postln;
	})
});
)

(
// =========================== 3. DEFINE A FUNCTION FOR DOING THE ANALYSIS ===================================
~analyze_to_dataset = {
	arg audio_buffer, slices_buffer, action; // the audio buffer to analyze, a buffer with the slice points, and an action to execute when done
	var features_buf = Buffer(s); // a buffer for writing the MFCC analyses into
	var stats_buf = Buffer(s);  // a buffer for writing the statistical summary of the MFCC analyses into
	var flat_buf = Buffer(s); // a buffer for writing only he mean MFCC values into
	var dataset = FluidDataSet(s); // the dataset that all of these analyses will be stored in
	~nmfccs = 13;


	slices_buffer.loadToFloatArray(action:{ // get the indices from the server loaded down to the language
		arg slices_array;
		fork{
			// iterate over each index in this array, paired with this next neighbor so that we know where to start
			// and stop the analysis
			slices_array.doAdjacentPairs{
				arg start_frame, end_frame, slice_index;
				var num_frames = end_frame - start_frame;

				"analyzing slice: % / %".format(slice_index + 1,slices_array.size - 1).postln;

				// mfcc analysis, hop over that 0th coefficient because it relates to loudness and here we want to focus on timbre
				FluidBufMFCC.processBlocking(s,audio_buffer,start_frame,num_frames,features:features_buf,startCoeff:1,numCoeffs:~nmfccs);

				// get a statistical summary of the MFCC analysis for this slice
				FluidBufStats.processBlocking(s,features_buf,stats:stats_buf,select:[\mean]);

				// extract and flatten just the 0th frame (numFrames:1) of the statistical summary (because that is the mean)
				FluidBufFlatten.processBlocking(s,stats_buf,destination:flat_buf);

				// now that the means are extracted and flattened, we can add this datapoint to the dataset:
				dataset.addPoint("slice-%".format(slice_index),flat_buf);

				if((slice_index % 100) == 99){s.sync};
			};

			s.sync;

			action.value(dataset); // execute the function and pass in the dataset that was created!
		};
	});
};
)

(
// ===================  4. DO THE ANALYSIS =====================
~analyze_to_dataset.(~source_buf,~source_indices_buf,{ // pass in the audio buffer of the source, and the slice points
	arg ds;
	~source_dataset = ds; // set the ds to a global variable so we can access it later
	~source_dataset.print;
});
)

/*
=================================================
|                                               |
|       LOAD AND ANALYZE THE TARGET             |
|                                               |
=================================================
*/

(
// ============= 5. LOAD THE FILE to play as the "real time" signal ===================
~target_path = FluidFilesPath("Nicol-LoopE-M.wav");
~target_buf = Buffer.read(s,~target_path);
)

/*
=================================================
|                                               |
|       KDTREE THE DATA AND DO THE LOOKUP       |
|                                               |
=================================================
*/

(
// ========== 6. FIT THE KDTREE TO THE SOURCE DATASET SO THAT WE CAN QUICKLY LOOKUP NEIGHBORS ===============
~kdtree = FluidKDTree(s);
~scaled_dataset = FluidDataSet(s);

// leave only one of these scalers *not* commented-out. try all of them!
~scaler = FluidStandardize(s);
//~scaler = FluidNormalize(s);
// ~scaler = FluidRobustScale(s);

~scaler.fitTransform(~source_dataset,~scaled_dataset);
~kdtree.fit(~scaled_dataset,{"kdtree fit".postln;});

~mfccbuf = Buffer.alloc(s,13);
~scaledbuf = Buffer.alloc(s,13);
)

(
// ========= 7. A LITTLE HELPER FUNCTION THAT WILL PLAY BACK A SLICE FROM THE SOURCE BY JUST PASSING THE INDEX =============
~play_source_index = {
	arg index, src_dur = 1;
	{
		var start_frame = Index.kr(~source_indices_buf,index); // lookup the start frame with the index *one the server* using Index.kr
		var end_frame = Index.kr(~source_indices_buf,index+1); // same for the end frame
		var num_frames = end_frame - start_frame;
		var dur_secs = min(num_frames / SampleRate.ir(~source_buf),src_dur);
		var sig = PlayBuf.ar(1,~source_buf,BufRateScale.ir(~source_buf),0,start_frame,0,2);
		var env = EnvGen.kr(Env([0,1,1,0],[0.03,dur_secs-0.06,0.03]),doneAction:2);
		// sig = sig * env; // include this env if you like, but keep the line above because it will free the synth after the slice!
		Out.ar(1,sig);
		nil;
	}.play;
};
)

// =========== 8. play the "real time" signal =================================
(
OSCdef(\find_neighbor,{
	~scaler.transformPoint(~mfccbuf,~scaledbuf);
	~kdtree.kNearest(~scaledbuf,1,{
		arg nearest;
		var int = nearest.asString.split($-)[1].asInteger;
		~play_source_index.(int);
	});
},"/find-neighbor");

{
	arg mfccbuf;
	var input = PlayBuf.ar(1,~target_buf,BufRateScale.ir(~target_buf),loop:1);
	var mfccs = FluidMFCC.kr(input,startCoeff:1);

	var trig = A2K.kr(Trig1.ar(FluidOnsetSlice.ar(input,9,0.1),ControlDur.ir));

	FluidKrToBuf.kr(mfccs,mfccbuf);

	SendReply.kr(trig,"/find-neighbor");
	input
}.play(args:[\mfccbuf,~mfccbuf]);
)