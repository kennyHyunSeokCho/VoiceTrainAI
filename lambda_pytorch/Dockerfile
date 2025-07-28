FROM public.ecr.aws/lambda/python:3.9

# 시스템 라이브러리 설치
RUN yum install -y \
    libsndfile \
    libsndfile-devel \
    ffmpeg \
    && yum clean all

# Python 패키지 설치
RUN pip install --upgrade pip \
    && pip install \
        torch==2.3.0+cpu \
        torchvision==0.18.0+cpu \
        torchaudio==2.3.0+cpu \
        --index-url https://download.pytorch.org/whl/cpu \
    && pip install librosa soundfile boto3 numpy nnAudio huggingface_hub scipy

WORKDIR ${LAMBDA_TASK_ROOT}

# Lambda 함수 및 모델 복사
COPY lambda_function.py .
COPY singer_identity ./singer_identity

# 모델 파일들이 올바르게 복사되었는지 확인
RUN ls -la singer_identity/ && \
    echo "Checking for model files:" && \
    find singer_identity -name "*.pt" -o -name "*.yaml" -o -name "*.yml"

# 환경 변수 설정 (librosa 캐싱 문제 해결)
ENV LIBROSA_CACHE_DIR=/tmp/librosa_cache
ENV JOBLIB_TEMP_FOLDER=/tmp/joblib_cache
ENV LIBROSA_CACHE_LEVEL=0
ENV LIBROSA_DISABLE_CACHE=1
ENV PYTHONPATH="${LAMBDA_TASK_ROOT}/singer_identity"

CMD ["lambda_function.lambda_handler"]
