import soundfile as sf
import numpy as np
import argparse
import json
import librosa
from nmf_decomposition import make_mags_from_basis_and_activation
from nmf_decomposition import make_complex_matrix_from_mags_and_phases
from nmf_decomposition import istft
from nmf_decomposition import write_to_file

def resynth_from_arbitrary_a_and_b(phases,activation,basis,fftSettings,sr):
    new_mags = make_mags_from_basis_and_activation(activation,basis)
    complex_matrix = make_complex_matrix_from_mags_and_phases(new_mags,phases)
    return istft(complex_matrix,fftSettings), sr

def resynthFromFiles(bases_data_path,activations_data_path,basis_index,activation_index):
    with open(bases_data_path,'r') as f:
        bases_data = json.loads(f.read())

    with open(activations_data_path,'r') as g:
        activations_data = json.loads(g.read())

    fftSettings = {'n_fft':bases_data['n_fft'],'hop_length':bases_data['hop_length']}
    
    audio_buffer, _ = librosa.load(activations_data['audio_path'],sr=None,mono=True)
    stft = librosa.stft(audio_buffer,**fftSettings)
    phases = np.angle(stft)

    activation = np.array(activations_data['acts'][activation_index])
    basis = np.array(bases_data['bases'][basis_index])
                   
    return resynth_from_arbitrary_a_and_b(phases,activation,basis,fftSettings,bases_data['sr'])

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='NMF resynthesis')
    parser.add_argument('--bases-data',type=str,required=True,help='path to json file containing NMF decomposition')
    parser.add_argument('--basis-index',type=int,required=True,help='index of basis to resynthesize')
    parser.add_argument('--activations-data',type=str,required=True,help='path to json file containing NMF decomposition')
    parser.add_argument('--activation-index',type=int,required=True,help='index of activation to resynthesize')
    parser.add_argument('--output-path',type=str,required=True,help='path to write resynthesized audio file')
    args = parser.parse_args()

    y, sr = resynthFromFiles(args.bases_data,args.activations_data,args.basis_index,args.activation_index)
    write_to_file(y,args.output_path,sr)