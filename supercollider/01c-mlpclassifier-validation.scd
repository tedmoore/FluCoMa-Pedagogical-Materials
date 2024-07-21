// two audio buffers to use as separate classes
(
~buffers = [
    Buffer.readChannel(s,FluidFilesPath("Tremblay-AaS-AcBassGuit-Melo-M.wav"),channels:[0]),
    Buffer.readChannel(s,FluidFilesPath("Tremblay-CEL-GlitchyMusicBoxMelo.wav"),channels:[0])
];
)

// strip any silence
(
fork{
    ~buffers = ~buffers.collect{
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
}
)

// take a look to see that the silence is stripped
(
~win = Window("FluidWaveform Test",Rect(0,0,1000,500));
~fws = ~buffers.collect{arg buf; FluidWaveform(buf, standalone: false)};
~win.view.layout = VLayout(~fws[0], ~fws[1]);
~win.front;
)

// analysis
(
fork{
    var features = Buffer(s);
    var flat = Buffer(s);
    var counter = 0;
    ~trainingData = FluidDataSet(s);
    ~trainingLabels = FluidLabelSet(s);
    ~testingData = FluidDataSet(s);
    ~testingLabels = FluidLabelSet(s);

    ~buffers.do{
        arg buf, buffer_i;
        FluidBufMFCC.processBlocking(s,buf,features:features,startCoeff:1);
        s.sync;
        features.numFrames.do{
            arg i;
            var id = "analysis-%".format(counter);
            FluidBufFlatten.processBlocking(s,features,i,1,destination:flat);
            if(0.8.coin){ // randomly: 80% of the time add to training data, 20% add to testing data
                ~trainingData.addPoint(id,flat);
                ~trainingLabels.addLabel(id,buffer_i);
            }{
                ~testingData.addPoint(id,flat);
                ~testingLabels.addLabel(id,buffer_i);
            };
            counter = counter + 1;
        };
    };

    s.sync;

    ~trainingData.print;
    ~trainingLabels.print;
    ~testingData.print;
    ~testingLabels.print;
};
)

// train!
(
~mlp = FluidMLPClassifier(s,[7],activation:FluidMLPClassifier.sigmoid,maxIter:100,learnRate:0.01,batchSize:1,validation:0.1);

~mlp.fit(~trainingData,~trainingLabels,{
    arg error;
    "current error: % ".format(error).postln;
});
)

// test!
(
~predictions = FluidLabelSet(s);
~mlp.predict(~testingData,~predictions,{
    ~predictions.dump({
        arg yhat;
        ~testingLabels.dump({
            arg labels;
            var wrong = 0;
            labels["data"].keysValuesDo{
                arg k, v;
                var label = v[0];
                var pred = yhat["data"][k][0];
                "id: %\t\tlabel: %\t\tprediction: %".format(k.padRight(14),label,pred).post;
                if(pred != label){
                    "\t\t* wrong".post;
                    wrong = wrong + 1;
                };
                "".postln;
            };
            "% / % were predicted incorrectly".format(wrong,labels["data"].size).postln;
        });
    });
});
)