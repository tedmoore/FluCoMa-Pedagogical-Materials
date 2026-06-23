// build a test signal and prepare some buffers
(
~sine = Buffer.loadCollection(s,Signal.sineFill(1024,({0} ! 19) ++ [1]));
~test_signal = Buffer.alloc(s,3072);
FluidBufCompose.processBlocking(s,~sine,gain:0.1,destination:~test_signal,destStartFrame:1024);
~features = Buffer(s);
)

// take a peek
~test_signal.plot;

/*
=====================================================================
We'll start with the default window size of 1024 and hop size of 512
and see how the padding changes the analysis
=====================================================================
*/
(
~show_me_data = {
	arg padding, window_size, hop_size;
	var analysis_start;

	padding.switch(
		0,{analysis_start = 0},
		1,{analysis_start = window_size / -2},
		2,{analysis_start = (window_size * -1) + hop_size}
	);

	FluidBufPitch.processBlocking(
		server:s,
		source: ~test_signal,
		features:~features,
		windowSize:window_size,
		hopSize:hop_size,
		padding:padding
	);

	// FluidWaveform(~test_signal,featuresBuffer:~features,stackFeatures:true);

	~features.loadToFloatArray(action:{
		arg fa;
		var string_padding = 4;
		var column_widths;
		fa = fa.round(0.001);
		fa = fa.clump(2);
		fa = fa.collect{
			arg features, i;
			var start = (analysis_start + (hop_size * i)).asInteger;
			var end = (start + window_size).asInteger;
			[start,end] ++ features;
		};
		fa = [["window-start","window-end","pitch","pitch conf"]] ++ fa;
		column_widths = fa.flop.collect{
			arg col;
			col.collect{arg f; f.asString.size }.maxItem;
		};
		fa.do{
			arg row, i;
			row.do{
				arg f, j;
				f.asString.padRight(column_widths[j]).post;
				{" ".post} ! string_padding;
			};
			"".postln;
			if(i == 0){
				column_widths.do{
					arg j;
					{"-".post} ! (j + string_padding);
				};
				"".postln;
			};
		};
	});
};
)

// Using the default of padding = 1, the first frame "begins" at negative half the window size
// any samples that have a "negative" index (before the second of audio we want to analyze)
// have an amplitude of zero
(
~show_me_data.(2,1024,256);
)