(
// 1. Instantiate some of the things we need.
Window.closeAll;
s.options.sampleRate_(48000);
s.options.device_("Fireface UC Mac (24006457)");
s.waitForBoot{
	Task{
		var win;
		~nMFCCs = 13;
		~trombone = Buffer.read(s,FluidFilesPath("Olencki-TenTromboneLongTones-M.wav"));
		~oboe = Buffer.read(s,FluidFilesPath("Harker-DS-TenOboeMultiphonics-M.wav"));
		~timbre_buf = Buffer.alloc(s,~nMFCCs);
		~ds = FluidDataSet(s);
		~labels = FluidLabelSet(s);
		~point_counter = 0;

		s.sync;

		win = Window("MFCCs",Rect(0,0,800,300));

		~mfcc_multislider = MultiSliderView(win,win.bounds)
		.elasticMode_(true)
		.size_(~nMFCCs);

		win.front;

	}.play(AppClock);
};
)

/*
2. Play some trombone sounds.
*/
(
{
	var sig = PlayBuf.ar(1,~trombone,BufRateScale.ir(~trombone),doneAction:2);
	var mfccs = FluidMFCC.kr(sig,~nMFCCs,40,1,maxNumCoeffs:~nMFCCs);
	mfccs.poll
	SendReply.kr(Impulse.kr(30),"/mfccs",mfccs);
	FluidKrToBuf.kr(mfccs,~timbre_buf);
	sig.dup;
}.play;

OSCFunc({
	arg msg;
	{~mfcc_multislider.value_(msg[3..].linlin(-30,30,0,1))}.defer;
},"\mfccs");
)

/*
3. When you know the MFCC buf has trombone timbre data in it
(because you hear trombone and see it in the multislider),
execute this next block to add points to the dataset and
labels to the label set.

Avoid adding points when there is silence inbetween trombone
tones, because... silence isn't trombone, so we don't want
to label it that way.

Try adding points continuously during the first three or so
trombone tones. We'll save the rest to test on later.
*/
(
var id = "example-%".format(~point_counter);
~ds.addPoint(id,~timbre_buf);
~labels.addLabel(id,"trombone");
~point_counter = ~point_counter + 1;
)

/*
4. Play some oboe sounds.
*/
(
{
	var sig = PlayBuf.ar(1,~oboe,BufRateScale.ir(~oboe),doneAction:2);
	var mfccs = FluidMFCC.kr(sig,~nMFCCs,40,1,maxNumCoeffs:~nMFCCs);
	SendReply.kr(Impulse.kr(30),"/mfccs",mfccs);
	FluidKrToBuf.kr(mfccs,~timbre_buf);
	sig.dup;
}.play;

OSCFunc({
	arg msg;
	{~mfcc_multislider.value_(msg[3..].linlin(-30,30,0,1))}.defer;
},"\mfccs");
)

/*
5. Add same as before.
*/
(
var id = "example-%".format(~point_counter);
~ds.addPoint(id,~timbre_buf);
~labels.addLabel(id,"oboe");
~point_counter = ~point_counter + 1;
)

/*
6. Make an MLPClassifier (neural network) to train. For more information about the parameters
visit: https://learn.flucoma.org/reference/mlpclassifier
*/
~mlpclassifier = FluidMLPClassifier(s,[5],1,learnRate:0.05,batchSize:5,validation:0.1);

/*
7. You may want to do a ".fit" more than once. For this task a loss value less than 0.01 would
be pretty good. Loss values however are always very relative so it's not really possible
to make objective observations about what one should "aim" for with a loss value. The best
way to know if a neural network is successfully performing the task you would like it to
is to test it. Probably using examples that it has never seen before.
*/
(
~mlpclassifier.fit(~ds,~labels,{
	arg loss;
	loss.postln;
});
)

/*
8. Make a prediction buffer to write the MLPClassifier's predictions into. The predictions that
it outputs to a buffer are integers. "0" will be represent what ever the "zeroth" example
label it saw was (because we always start counting from zero in these cases). "1" will represent
the "first" example label it saw, etc.
*/
~prediction_buf = Buffer.alloc(s,1);

/*
9. Play some trombone sounds and make some predictions. It should show a 0.
*/
(
{
	var sig = PlayBuf.ar(1,~trombone,BufRateScale.ir(~trombone),doneAction:2);
	var mfccs = FluidMFCC.kr(sig,~nMFCCs,40,1,maxNumCoeffs:~nMFCCs);
	FluidKrToBuf.kr(mfccs,~timbre_buf);
	~mlpclassifier.kr(Impulse.kr(30),~timbre_buf,~prediction_buf);
	FluidBufToKr.kr(~prediction_buf).poll;
	sig.dup;
}.play;
)

/*
10. Play some oboe sounds and make some predictions. It should show a 1.
*/
(
{
	var sig = PlayBuf.ar(1,~oboe,BufRateScale.ir(~oboe),doneAction:2);
	var mfccs = FluidMFCC.kr(sig,~nMFCCs,40,1,maxNumCoeffs:~nMFCCs);
	FluidKrToBuf.kr(mfccs,~timbre_buf);
	~mlpclassifier.kr(Impulse.kr(30),~timbre_buf,~prediction_buf);
	FluidBufToKr.kr(~prediction_buf).poll;
	sig.dup;
}.play;
)

/*
11. During the silences it is reporting either trombone or oboe, because that's all
it knows about. Try adding a loudness threshold using FluidLoudness so it only makes
predictions if there is sound above a certain loudness present.
*/