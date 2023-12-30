import librosa
import librosa.display
import numpy as np
import matplotlib.pyplot as plt
import soundfile as sf

def resynthComponent(stft,basis,activation,outpath,fftSettings):
    Y = np.outer(basis, activation) * np.exp(1j * np.angle(stft))
    y = librosa.istft(Y,**fftSettings)
    sf.write(outpath,y,sr,subtype='PCM_24')

# Replace 'your_audio_file.wav' with the path to your audio file
# audio_file_path = '../audio-files/Nicol-LoopE-M.wav' 
audio_file_path = '../audio-files/Tremblay-BaB-SoundscapeGolcarWithDog.wav'
n_components = 2
sr = 44100
fftSettings = {'n_fft':1024,'hop_length':512}

y, sr = librosa.load(audio_file_path,sr=sr,duration=3)
print(audio_file_path,sr)

stft = librosa.stft(y,**fftSettings)

print(f'stft shape: {stft.shape[0]} mags, {stft.shape[1]} frames')

bases, activations = librosa.decompose.decompose(np.abs(stft), n_components=n_components)
bases = np.transpose(bases)

print(f'bases shape: {bases.shape}')
print(f'activations shape: {activations.shape}')

plt.figure(figsize=(12, 8))

plt.subplot(3, 1, 1)
librosa.display.specshow(librosa.amplitude_to_db(np.abs(stft)), sr=sr, x_axis='time', y_axis='log')
plt.title('Original Spectrogram')

plt.subplot(3, 1, 2)
for basis in bases:
    plt.plot(basis)
plt.title('NMF Bases')

plt.subplot(3, 1, 3)
for activation in activations:
    plt.plot(activation)
plt.title('NMF Activations')

for i in range(n_components):
    resynthComponent(stft,bases[i],activations[i],f'librosa-component-{i}.wav',fftSettings)

plt.tight_layout()
plt.show()
