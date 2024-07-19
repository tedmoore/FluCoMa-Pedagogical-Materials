import torch
from torchnmf.nmf import NMF
import argparse
import numpy as np
from pathlib import Path
import librosa
import torch.nn.functional as F
import gc
import time

def getStem(path):
    return Path(path).stem

def recombine_components(vectors_a, vectors_b):
    components = torch.empty((vectors_a.shape[1],vectors_a.shape[0],vectors_b.shape[1]),device=vectors_a.device,dtype=vectors_a.dtype)
    for component_i in range(vectors_b.shape[0]):
            components[component_i] = torch.outer(vectors_a[:,component_i],vectors_b[component_i])
    return components

def delete_me(tensors):
    if not isinstance(tensors,list):
        tensors = [tensors]
    for t in tensors:
        del t
    gc.collect()

def crop_audio(y,sr,start,dur):
    dur = dur or y.shape[0] / sr
    start_sample = int(start * sr)
    end_sample = int((start + dur) * sr)
    return y[start_sample:end_sample]

def decompose_audio(audio):
    stft = librosa.stft(audio)
    mags = np.abs(stft)
    mags_torch = torch.tensor(mags,dtype=torch.float32,device=torch_device).t()

    # nmf on audio
    model = NMF(mags_torch.shape,rank=args.n_components)
    model.to(torch_device)
    model.fit(mags_torch,max_iter=200)
    audio_a = model.H
    audio_b = model.W.T
    del model
    del mags_torch
    gc.collect()

if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--torch-device', default='mps', type=str,choices=['cpu','mps'])
    parser.add_argument('--audio',type=str,required=True)
    parser.add_argument('--n-components',type=int,default=3)
    parser.add_argument('--n_fft',type=int,default=1024,choices=[256,512,1024,2048,4096,8192])
    parser.add_argument('--hop_length',type=int)
    args = parser.parse_args()

    args.hop_length = args.hop_length or args.n_fft // 2
    torch_device = torch.device(args.torch_device)

    # load audio
    print('loading audio...')
    audio, sr = librosa.load(args.audio,sr=None,mono=True)
    
    seconds = [1,10,30,60,60 * 2, 60 * 5, 60 * 10]

    for sec in seconds:
        a = crop_audio(audio,sr,0,sec)
        starttime = time.time()
        decompose_audio(a)
        dur = time.time() - starttime
        print(f'{sec} seconds of audio took {dur} seconds: {dur / sec} of total duration')
