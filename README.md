# Access System Face Detector

A local face-recognition pipeline for access control systems:
- Capture frames from a webcam
- Face detection and alignment (MediaPipe)
- Embedding extraction (ArcFace ResNet100 via OpenVINO)
- Embedding validation via a local cache (Redis Stack) and an external API

The project is oriented toward Windows, but the logic is cross‑platform.

## Features
- Real-time processing
- Face alignment using MediaPipe FaceAligner
- 512‑D ArcFace embeddings (ONNX → OpenVINO)
- Fast cache lookup (Redis vector KNN) + fallback API request
- Simple, thread-based pipeline architecture

## Architecture
Components and threads (see `cmd/main.py`):
- VideoCapture → writes the latest frame into `shared_frames['latest']`
- DetectionMediaPipe → detects faces, draws overlays, aligns face; puts aligned face into `face['aligned']` and annotated frame into `shared_frames['processed']`
- VideoStream → displays a window; press ESC to close
- RecognitionArcFace → computes the embedding and writes it to `shared_embedding['latest']`
- EmbeddingValidation → looks up the nearest embedding in Redis; on a miss, calls external API `POST /api/v1/embedding/validate`

Global settings are currently defined directly in code (minimal):
- FPS (in `cmd/main.py`)
- OpenVINO device: `device='GPU'` (see `RecognitionArcFace`) — switch to `CPU` if no GPU is available
- Redis default: `localhost:6379`, `db=0`

## Dependencies
See `requirements.txt`. Key libraries:
- Python 3.11
- OpenVINO Runtime
- MediaPipe
- OpenCV, NumPy
- redis (client), requests, loguru

Redis Stack (Vector KNN) is used for caching. It runs as a separate Docker service.

## Models
The `models/` folder already contains necessary artifacts:
- `arcfaceresnet100-8.onnx` — ArcFace ResNet100 (https://github.com/openvinotoolkit/open_model_zoo/blob/master/models/public/face-recognition-resnet100-arcface-onnx/README.md)
- `face_landmarker.task` — model for MediaPipe FaceAligner (https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task)

Model paths are hard-coded:
- ArcFace: `models/arcfaceresnet100-8.onnx` (see `src/recognition.py`)
- FaceAligner: `models/face_landmarker.task` (see `src/detection.py`)

## Quick start (Windows and cross-platform)
Use the provided convenience scripts which run Docker Compose, ensure a virtualenv exists and is activated, install requirements if needed, set `PYTHONPATH`, and finally start the application:

- PowerShell (recommended on Windows):

```powershell
# from project root
.\scripts\run.ps1
```

- Bash (Linux / macOS):

```bash
# from project root
./scripts/run.sh
```

Notes:
- `scripts/run.ps1` runs Docker Compose, sets `$ENV:PYTHONPATH` to the repository root, creates/activates `.venv` if missing, installs `requirements.txt`, and runs `python cmd\main.py`.
- `scripts/run.sh` does the same for Unix-like shells (bash).
- If you prefer to manage services manually, you can run the `docker compose` command above and then start the app manually (see Step 3).

## Configuration
- FPS: change in `cmd/main.py` (variable `fps`)
- OpenVINO device: in `src/recognition.py` when creating `RecognitionArcFace(..., device='GPU' | 'CPU')`
- Redis parameters: in `cmd/main.py` when creating `VerifiedEmbeddingsCache(log, host, port, db, password)`
- Validation API: URL in `api/access_system.py` (`http://localhost:8081/api/v1/embedding/validate`)

### External API contract
On a cache miss, `EmbeddingValidation` calls `POST /api/v1/embedding/validate`:
- URL: `http://localhost:8081/api/v1/embedding/validate`
- Request body (JSON):
```json
{
  "vector": [float, float, ..., float] 
}
```
- Response handling: `200 OK` is treated as “found”. Any other code is treated as “embedding not found”.

## Cache details and similarity threshold
- Index: `FLAT` vector, `COSINE`
- Embedding size: 512
- Storage: key `doc:{sha256}`, field `embedding` (bytes), TTL 1 hour
- Verification: fetches the single nearest neighbor; similarity interpreted as `1.0 - score`; current threshold is > 0.5 (see `verify_embedding`)

## Project structure
- `cmd/main.py` — entry point, thread orchestration
- `src/video_capture.py` — video capture
- `src/detection.py` — face detection and alignment (MediaPipe)
- `src/recognition.py` — ArcFace inference (OpenVINO), embedding normalization
- `src/validation.py` — cache lookup and API call
- `src/cache.py` — Redis Stack KNN (index, storage, search)
- `src/config.py` — runtime configuration and constants
- `src/utils.py` — utility helpers (image processing, I/O, logging)
- `api/access_system.py` — REST API wrapper for validation
- `docker/docker-compose.yaml` — Redis Stack and supporting services
- `models/` — model files
- `scripts/` — convenience runners (`run.ps1`, `run.sh`)
- `tests/` — unit and integration tests
- `requirements.txt` — Python dependencies
- `README.md` — project documentation (this file)
