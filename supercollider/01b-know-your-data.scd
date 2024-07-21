/*

this code assumes that the use case for comparing these two sounds will be done in real time.
therefore it makes *each* fft frame's mfcc analysis it's own data point, to get a sense of
what the data might look like in a real time audio stream. before doing this, it strips out
any silence that might be in the sound file so that it doesn't categorize silence as "bass"
or "music box".

*/

// two audio buffers to use as separate classes
(
~dir = thisProcess.nowExecutingPath.dirname;
s.waitForBoot{
	var mfccbuf = Buffer(s);
	var specbuf = Buffer(s);
	var pitchbuf = Buffer(s);
	var loudnessbuf = Buffer(s);
	var flat = Buffer(s);
	var point = Buffer(s);
	var counter = 0;
	var headers;

	var frameToChannel = {
		arg src, frame, startFrame;
		FluidBufFlatten.processBlocking(s,src,frame,1,destination:flat);
		FluidBufCompose.processBlocking(s,flat,destination:point,destStartFrame:startFrame);
	};

	var trainingData = FluidDataSet(s);
	var trainingLabels = FluidLabelSet(s);

	var buffers = [
		Buffer.readChannel(s,FluidFilesPath("Tremblay-AaS-AcBassGuit-Melo-M.wav"),channels:[0]),
		Buffer.readChannel(s,FluidFilesPath("Tremblay-CEL-GlitchyMusicBoxMelo.wav"),channels:[0])
	];

	s.sync;

	buffers = buffers.collect{
		arg src;
		var indices = Buffer(s);
		var temp = Buffer(s);
		FluidBufAmpGate.processBlocking(s,src,indices:indices,onThreshold:-30,offThreshold:-35,minSliceLength:4410);
		indices.loadToFloatArray(action:{
			arg fa;
			var curr = 0;
			fa.clump(2).do{
				arg arr;
				var start = arr[0];
				var num = arr[1] - start;
				FluidBufCompose.processBlocking(s,src,start,num,destination:temp,destStartFrame:curr);
				curr = curr + num;
			};
			indices.free;
			src.free;
		});
		temp;
	};

	s.sync;

	"done stripping silence".postln;

	// analysis

	buffers.do{
		arg buf, buffer_i;

		FluidBufMFCC.processBlocking(s,buf,features:mfccbuf);
		FluidBufSpectralShape.processBlocking(s,buf,features:specbuf);
		FluidBufPitch.processBlocking(s,buf,features:pitchbuf);
		FluidBufLoudness.processBlocking(s,buf,features:loudnessbuf);

		s.sync;

		mfccbuf.numFrames.do{
			arg i;
			var id = "analysis-%".format(counter);

			frameToChannel.(mfccbuf,i,0);
			frameToChannel.(specbuf,i,13);
			frameToChannel.(pitchbuf,i,20);
			frameToChannel.(loudnessbuf,i,22);

			trainingData.addPoint(id,point);
			trainingLabels.addLabel(id,["bass","music-box"][buffer_i]);

			counter = counter + 1;

			i.postln;

			if(i % 100 == 99){s.sync};
		};
	};

	// make headers
	headers = List.new;
	headers.addAll(13.collect{arg i; "mfcc-%".format(i.asString.padLeft(2,"0"))});
	headers.addAll(FluidSpectralShape.features);
	headers.addAll(FluidPitch.features);
	headers.addAll(FluidLoudness.features);

	s.sync;

	trainingData.print;
	trainingLabels.print;
	trainingData.write("%/01b-training-data.json".format(~dir));
	trainingLabels.write("%/01b-training-labels.json".format(~dir));

	// PlotXYColor: https://github.com/tedmoore/PlotXYColor
	PlotXYColor.fromFluidDataSet(trainingData,trainingLabels,headerArray:headers.asArray)
}
)
