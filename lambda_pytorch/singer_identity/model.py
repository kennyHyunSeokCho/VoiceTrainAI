import torch
import torch.nn as nn
import torch.nn.functional as F
from typing import Optional, List, Callable, Union
import torchaudio.transforms as T
from nnAudio import features
import os
import shutil
import warnings

from .utils.fetch_pretrained import from_hparams, from_scripted
from .models.network_components import get_vision_backbone, LogScale, Grey2Rgb

# Lambda 쓰기 가능한 임시 폴더
TMP_MODEL_DIR = "/tmp/singer_identity"
os.makedirs(TMP_MODEL_DIR, exist_ok=True)

# 기본 모델 디렉토리
DEFAULT_MODEL_DIR = os.path.abspath(os.path.dirname(__file__))


class FeatureExtractor(nn.Module):
    def __init__(self, spec_layer: str = "melspectogram", n_fft: int = 2048,
                 hop_length: int = 512, **kwargs):
        super().__init__()
        if spec_layer == "melspectogram":
            n_mels = kwargs.get("n_mels", 128)
            self.spec_layer = features.MelSpectrogram(
                n_fft=n_fft, hop_length=hop_length, verbose=False, n_mels=n_mels
            )
        elif spec_layer == "stft":
            self.spec_layer = features.STFT(
                n_fft=n_fft, hop_length=hop_length, verbose=False,
                output_format="Magnitude", **kwargs
            )
        else:
            raise NotImplementedError

    def forward(self, x):
        return self.spec_layer(x)


class Encoder(nn.Module):
    def __init__(self, backbone="efficientnet_b0", embedding_dim=1000,
                 pretrained=False, **kwargs):
        super().__init__()
        encoder_backbone = get_vision_backbone(
            vismod=backbone,
            num_classes=embedding_dim,
            pretrained=pretrained,
            **kwargs,
        )
        self.net = nn.Sequential(LogScale(), Grey2Rgb(), encoder_backbone)

    def forward(self, x):
        return self.net(x)


class Projection(nn.Module):
    def __init__(self, input_dim=1000, output_dim=128, nonlinearity=None,
                 is_identity=False, l2_normalize=False):
        super().__init__()
        self.l2_normalize = l2_normalize
        self.is_identity = is_identity
        if is_identity:
            self.net = nn.Identity()
        else:
            if nonlinearity is None:
                nonlinearity = torch.nn.SiLU()
            self.net = nn.Sequential(nonlinearity, torch.nn.Linear(input_dim, output_dim))

    def forward(self, x):
        projection = self.net(x)
        if self.l2_normalize and not self.is_identity:
            projection = F.normalize(projection, dim=-1)
        return projection


class IdentityEncoder(nn.Module):
    def __init__(self, feature_extractor, encoder):
        super().__init__()
        self.feature_extractor = FeatureExtractor(**feature_extractor)
        self.encoder = Encoder(**encoder)

    def forward(self, x):
        return self.encoder(self.feature_extractor(x))


def _ensure_tmp_model_files(source_dir):
    """ /var/task/singer_identity 에 있는 model.pt, hyperparams.yaml을 /tmp로 복사 """
    print(f"Ensuring model files from {source_dir} to {TMP_MODEL_DIR}")
    
    # 소스 디렉토리가 존재하는지 확인
    if not os.path.exists(source_dir):
        raise FileNotFoundError(f"Source directory does not exist: {source_dir}")
    
    for fname in ["model.pt", "hyperparams.yaml"]:
        src = os.path.join(source_dir, fname)
        dst = os.path.join(TMP_MODEL_DIR, fname)
        
        print(f"Checking {fname}: src={src}, dst={dst}")
        print(f"Source exists: {os.path.exists(src)}, Destination exists: {os.path.exists(dst)}")
        
        if os.path.exists(src):
            if not os.path.exists(dst):
                try:
                    shutil.copy2(src, dst)  # copy2는 메타데이터도 복사
                    print(f"Successfully copied {fname} to {dst}")
                except Exception as e:
                    print(f"Failed to copy {fname}: {e}")
                    raise
            else:
                print(f"Destination file {dst} already exists, skipping copy")
        else:
            raise FileNotFoundError(f"Required model file not found: {src}")
    
    return TMP_MODEL_DIR


def load_model(model=".", source=None, torchscript=False, savedir=None, input_sr=44100):
    """ /tmp 경로를 활용하여 모델 로드 """
    if source is None:
        source = DEFAULT_MODEL_DIR

    print(f"Loading model with source={source}, model={model}")
    
    model_dir = _ensure_tmp_model_files(source)
    hparams_path = os.path.join(model_dir, "hyperparams.yaml")
    weights_path = os.path.join(model_dir, "model.pt")

    print(f"Model files - hparams: {hparams_path}, weights: {weights_path}")
    print(f"Files exist - hparams: {os.path.exists(hparams_path)}, weights: {os.path.exists(weights_path)}")

    if not os.path.exists(hparams_path):
        raise FileNotFoundError(f"hyperparams.yaml not found at: {hparams_path}")
    if not os.path.exists(weights_path):
        raise FileNotFoundError(f"model.pt not found at: {weights_path}")

    # savedir을 /tmp로 설정하여 pretrained_models가 /tmp에 생성되도록 함
    if savedir is None:
        savedir = "/tmp/pretrained_models"
    
    try:
        if torchscript:
            model = from_scripted(f"{model}/model.ts", source, savedir=savedir)
        else:
            model = from_hparams(
                IdentityEncoder,
                model_dir,
                hparams_file=hparams_path,
                weights_file=weights_path,
                savedir=savedir,
            )
        print("Model loaded successfully")
    except Exception as e:
        print(f"Failed to load model: {e}")
        raise

    if input_sr != 44100:
        feature_extractor = model.feature_extractor
        model.feature_extractor = nn.Sequential(T.Resample(input_sr, 44100), feature_extractor)
        print(f"Resampling input from {input_sr} to 44100 Hz")

    return model
