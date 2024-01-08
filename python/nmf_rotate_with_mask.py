import argparse
from nmf_decomposition import decompose, create_fftSettings_from_args
from nmf_decomposition import make_mags_from_basis_and_activation
from nmf_decomposition import balance_mags_via_softmask
from nmf_decomposition import make_complex_matrix_from_mags_and_phases
from nmf_decomposition import istft
from nmf_decomposition import write_to_file
import librosa
import numpy as np

def path_to_audio_data(path,fftSettings):
    y, sr = librosa.load(path,sr=None,mono=True)
    dict = {'sr':sr,'y':y}
    dict['stft'] = librosa.stft(y,**fftSettings)
    dict['mags'] = np.abs(dict['stft'])
    dict['phases'] = np.angle(dict['stft'])
    return dict

def grow_size_if_needed(phases_for_masking, balanced_mags):
    # Check if phases_for_masking is smaller than balanced_mags
    if phases_for_masking.flatten().size < balanced_mags.flatten().size:
        # Resize phases_for_masking to match the shape of balanced_mags
        phases_for_masking = np.resize(phases_for_masking, balanced_mags.shape)
    # Return phases_for_masking (resized if needed)
    return phases_for_masking

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='NMF rotate activations and bases to be mismatched, but then upon resynthesis, use masking strategy on different file **the results are not very interesting**')
    parser.add_argument('--audio-path-to-decompose',type=str,required=True)
    parser.add_argument('--audio-path-to-mask',type=str,required=True)
    parser.add_argument('--n-components',type=int,required=True)
    parser.add_argument('--n_fft',type=int,choices=[int(2**i) for i in range(8,14)],required=False,default=1024)
    parser.add_argument('--hop_length',required=False,type=int)
    args = parser.parse_args()

    fftSettings = create_fftSettings_from_args(args)

    audio_for_decomposition = path_to_audio_data(args.audio_path_to_decompose,fftSettings)
    audio_for_masking = path_to_audio_data(args.audio_path_to_mask,fftSettings)

    bases, acts = decompose(audio_for_decomposition['mags'],args.n_components)

    # rotate bases
    # bases = np.roll(bases,-1,axis=0)

    recombined_mags = [make_mags_from_basis_and_activation(acts[i],bases[i]) for i in range(args.n_components)]
    balanced_mags = balance_mags_via_softmask(recombined_mags,audio_for_masking['mags'])
    for i in range(args.n_components):
        print(f'balanced mags {i} shape: {balanced_mags[i].shape}')
        print(f'audio for masking mags shape: {audio_for_masking["mags"].shape}')
        phases_for_resynth = grow_size_if_needed(audio_for_masking['phases'],balanced_mags[i])
        complex_matrix = make_complex_matrix_from_mags_and_phases(balanced_mags[i],phases_for_resynth)
        resynthsized_y = istft(complex_matrix,fftSettings)
        write_to_file(resynthsized_y,f'rotated-with-mask-{i}.wav',audio_for_masking['sr'])