docker-compose -f "docker\docker-compose.yaml" up --build -d

$ENV:PYTHONPATH = $PWD

if (Test-Path -Path ".\.venv" -PathType Container) {
    .\.venv\Scripts\Activate.ps1
} else {
    py -3.11 -m venv .venv
    & .\.venv\Scripts\Activate.ps1
    & .\.venv\Scripts\python.exe -m pip install --upgrade pip
    & .\.venv\Scripts\pip.exe install -r requirements.txt
}

python "cmd\main.py"