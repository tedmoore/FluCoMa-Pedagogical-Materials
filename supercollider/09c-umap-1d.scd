s.options.device = "ZoomAudioD"

// 0. load buffer

~src = Buffer.readChannel(s,"/Users/ted/Documents/_TEACHING/_materials/flucoma/FluCoMa-Pedagogical-Materials-repo/max/synth-sounds/from-with-luke-006.wav",channels:[0]);
// ~src = Buffer.read(s,FluidFilesPath("Nicol-LoopE-M.wav"));
// ~src = Buffer.read(s,FluidFilesPath("Green-Box641.wav"));
// ~src = Buffer.read(s,FluidFilesPath("Harker-DS-TenOboeMultiphonics-M.wav"));
// ~src = Buffer.read(s,FluidFilesPath("Olencki-TenTromboneLongTones-M.wav"));

~src.play(mul:-20.dbamp); // listen if you want;

// 1. analyze
(
var current_frame = 0;
var featuresBuf = Buffer(s);
var stats = Buffer(s);
var flat = Buffer(s);
~slice_frames = 0.1 * ~src.sampleRate;
~ds = FluidDataSet(s);
~counter = 0;
fork{
	while({
		current_frame + ~slice_frames < ~src.numFrames;
	},{
		FluidBufMFCC.processBlocking(s,~src,current_frame,~slice_frames,features:featuresBuf,startCoeff:0,numCoeffs:40);
		// FluidBufChroma.processBlocking(s,~src,current_frame,~slice_frames,features:featuresBuf);
		// FluidBufPitch.processBlocking(s,~src,current_frame,~slice_frames,features:featuresBuf,unit:1,windowSize:2048);
		// FluidBufSpectralShape.processBlocking(s,~src,current_frame,~slice_frames,features:featuresBuf,unit:1);
		FluidBufStats.processBlocking(s,featuresBuf,stats:stats);
		FluidBufFlatten.processBlocking(s,stats,numFrames:1,destination:flat);
		~ds.addPoint(current_frame.asInteger,flat);

		if((~counter % 100) == 99) {s.sync;};
		"current frame: % / %\t%".format(current_frame,~src.numFrames,current_frame/~src.numFrames).postln;

		current_frame = current_frame + ~slice_frames;
		~counter = ~counter + 1;
	});

	s.sync;

	"done".postln;
}
)

~ds.print;

// scale if our dimensions are in different ranges.
FluidStandardize(s).fitTransform(~ds,~ds);

~ds.print;

// 2. UMAP
(
~ds_umap = FluidDataSet(s);
FluidUMAP(s,1).fitTransform(~ds,~ds_umap,{"umap complete".postln;});
)

~ds_umap.print;

// 3. sort
(
~ds_umap.dump({
	arg dict;
	var points = dict["data"].keys.collect{
		arg k;
		[k,dict["data"][k][0]]
	}.asArray;
	var sorted_points = points.sort({arg a, b; a[1] < b[1]}).collect{arg pt; pt[0].interpret};

	~sorted_start_frames = Buffer.loadCollection(s,sorted_points);
	sorted_points.postln;
})
)

~sorted_start_frames.plot

// 4. recombine
(
fork({
	var overlap = 2;
	var hopSize = ~slice_frames / overlap;
	var hopDur = hopSize / ~src.sampleRate;
	var trigFreq = hopDur.reciprocal;
	var win, uv, startFrame = 0;

	Window.closeAll;

	win = Window(bounds:Rect(0,0,1600,400));
	FluidWaveform(~src,parent:win,bounds:Rect(0,0,win.bounds.width,win.bounds.height));
	1.wait;
	uv = UserView(win,Rect(0,0,win.bounds.width,win.bounds.height))
	.drawFunc_{
		var x = startFrame.linlin(0,~src.numFrames,0,win.bounds.width);
		// x.postln;
		Pen.color_(Color.red);
		Pen.addRect(Rect(x,0,2,win.bounds.height));
		Pen.fill;
	};

	{
		var trig = Impulse.ar(trigFreq);
		var index = (PulseCount.ar(trig) - 1);
		var startFrame_ = Index.kr(~sorted_start_frames,index);
		var centerFrame = startFrame_ + (hopSize/2);
		var centerSeconds = centerFrame / ~src.sampleRate;
		var dur = ~slice_frames / ~src.sampleRate;
		FreeSelf.kr(index > BufFrames.ir(~sorted_start_frames));
		SendReply.ar(trig,"/startFrame",startFrame_);
		TGrains.ar(2,trig,~src,BufRateScale.ir(~src),centerSeconds,dur,TRand.ar(-1.0,1.0,trig));
	}.play;

	OSCdef(\startFrame,{
		arg msg;
		startFrame = msg[3];
		{win.refresh}.defer;
	},"/startFrame");

	win.front;
},AppClock);
)