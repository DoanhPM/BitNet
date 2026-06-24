param(
    [string]$EnvName = "bitnet-cpp",
    [string]$Model = "models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf",
    [string]$Prompt = "You are a helpful assistant.",
    [int]$Threads = 4,
    [int]$Tokens = 128,
    [int]$Context = 2048,
    [double]$Temperature = 0.8,
    [string]$CondaExe = "",
    [switch]$Conversation,
    [switch]$Interactive
)

$ErrorActionPreference = "Stop"
$env:PYTHONNOUSERSITE = "1"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

function Resolve-CondaExe {
    param([string]$Requested)

    if ($Requested -and (Test-Path $Requested)) {
        return (Resolve-Path $Requested).Path
    }

    $cmd = Get-Command "conda" -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    $candidates = @(
        (Join-Path $env:USERPROFILE "anaconda3\Scripts\conda.exe"),
        (Join-Path $env:USERPROFILE "miniconda3\Scripts\conda.exe"),
        "C:\ProgramData\anaconda3\Scripts\conda.exe",
        "C:\ProgramData\miniconda3\Scripts\conda.exe"
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    throw "conda was not found. Open Anaconda PowerShell Prompt or pass -CondaExe C:\path\to\conda.exe."
}

$argsList = @(
    "run_inference.py",
    "-m", $Model,
    "-p", $Prompt,
    "-t", "$Threads",
    "-n", "$Tokens",
    "-c", "$Context",
    "-temp", "$Temperature"
)

if ($Conversation) {
    $argsList += "-cnv"
}

if ($Interactive) {
    $argsList += "-i"
}

$Conda = Resolve-CondaExe $CondaExe
& $Conda run -n $EnvName python @argsList
