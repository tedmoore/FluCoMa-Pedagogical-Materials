from sklearn.decomposition import NMF
import numpy as np
import argparse
import json
import librosa
import librosa.display
import matplotlib.pyplot as plt

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Seed NMF with Bases')

    # currently the seed data is coming from the same file for the bases and activations
    # would it even make sense to use different files for bases and activations?
    parser.add_argument('--seed-data',type=str,required=True,help='path to json file containing NMF decomposition with bases to seed NMF process')
    parser.add_argument('--audio-path-to-analyze',type=str,required=True,help='path to audio file to decompose')
    parser.add_argument('--bases-mode',type=str,required=True,choices=['random','seed'],help='mode for bases: random or seed')
    parser.add_argument('--activations-mode',type=str,required=True,choices=['random','seed'],help='mode for activations: random or seed')
    args = parser.parse_args()

    with open(args.seed_data,'r') as f:
        seed_data = json.loads(f.read())

    fftSettings = {'n_fft':seed_data['fftSize'],'hop_length':seed_data['hopSize']}
    
    audio_buffer, sr = librosa.load(args.audio_path_to_analyze,sr=None,mono=True)
    stft = librosa.stft(audio_buffer,**fftSettings)
    matrix = np.transpose(np.abs(stft,dtype=np.float64))

    if args.bases_mode == 'random':
        bases = np.random.rand(matrix.shape[0],seed_data['n_components'])
    elif args.bases_mode == 'seed':
        bases = np.transpose(np.array(seed_data['bases']))
    
    if args.activations_mode == 'random':
        activations = np.random.rand(seed_data['n_components'],matrix.shape[1]) # random activations because we just want to seed bases
    elif args.activations_mode == 'seed':
        activations = np.array(seed_data['activations'])

    model = NMF(n_components=seed_data['n_components'],init='custom',solver='mu',beta_loss='kullback-leibler')

    new_acts = model.fit_transform(matrix, W=bases, H=activations)
    new_bases = model.components_
    new_acts = np.transpose(new_acts)

    plt.figure(figsize=(12, 8))

    plt.subplot(3, 1, 1)
    librosa.display.specshow(librosa.amplitude_to_db(matrix), sr=sr, x_axis='time', y_axis='log')
    plt.title('Spectrogram')

    plt.subplot(3, 1, 2)
    for new_acts in new_acts:
        plt.plot(new_basis)
    plt.title('NMF Acts')

    plt.subplot(3, 1, 3)
    for new_basis in new_bases:
        plt.plot(new_basis)
    plt.title('NMF Bases')

    plt.tight_layout()
    plt.show()