import json
import numpy as np
import argparse
import librosa
import librosa.display
import matplotlib.pyplot as plt
from sklearn.decomposition import NMF
from nmf_decomposition import plot_nmf
import time

def nmf_match(audio_buffer,bases,fftSettings,sr):

    fftSettings = {} if fftSettings is None else fftSettings
    fftSettings['n_fft'] = 1024 if 'n_fft' not in fftSettings else fftSettings['n_fft']
    fftSettings['hop_length'] = 512 if 'hop_length' not in fftSettings else fftSettings['hop_length']

    stft = librosa.stft(audio_buffer,**fftSettings)
    matrix = np.transpose(np.abs(stft,dtype=np.float64))

    print(f'matrix shape: {matrix.shape}')
    print(f'bases shape: {bases.shape}')

    nmfSettings = {}
    nmfSettings['n_components'] = bases.shape[0]
    nmfSettings['init'] = 'custom'
    nmfSettings['solver'] = 'mu'
    nmfSettings['beta_loss'] = 'kullback-leibler'

    nmf = NMF(**nmfSettings)

    new_activations = []
    start_time = time.time()
    for i,fft_frame in enumerate(matrix):
        print(f'frame {i} / {matrix.shape[0]}')
        new_acts, _, _ = nmf._fit_transform(X=np.array([fft_frame]),H=bases,update_H=False)
        new_activations.append(new_acts[0])

    end_time = time.time()
    print(f'elapsed time: {end_time-start_time}')

    new_activations = np.transpose(new_activations)
    plot_nmf(stft,new_activations,bases,sr)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='NMF match')
    parser.add_argument('--bases-data',type=str,required=True,help='path to json file containing NMF decomposition')
    parser.add_argument('--audio-path',type=str,required=True,help='path to audio file to match')
    args = parser.parse_args()

    with open(args.bases_data,'r') as f:
        bases_data = json.loads(f.read())
    
    fftSettings = {'n_fft':bases_data['n_fft'],'hop_length':bases_data['hop_length']}

    audio_buffer, sr = librosa.load(args.audio_path,sr=None,mono=True)

    nmf_match(audio_buffer,np.array(bases_data['bases']),fftSettings,sr)