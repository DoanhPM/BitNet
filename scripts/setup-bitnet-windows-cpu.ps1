param(
    [string]$EnvName = "bitnet-cpp",
    [string]$PythonVersion = "3.9",
    [string]$ModelRepo = "microsoft/BitNet-b1.58-2B-4T-gguf",
    [string]$ModelDir = "models/BitNet-b1.58-2B-4T",
    [ValidateSet("i2_s", "tl2")]
    [string]$QuantType = "i2_s",
    [string]$CondaExe = "",
    [switch]$SkipModelDownload,
    [switch]$SkipBuild,
    [switch]$UsePretuned,
    [switch]$NoCleanBuild,
    [switch]$InstallBuildTools
)

$ErrorActionPreference = "Stop"
$env:PYTHONNOUSERSITE = "1"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Test-Command {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

function Invoke-Checked {
    param([string]$Label, [scriptblock]$Command)
    Write-Step $Label
    $global:LASTEXITCODE = 0
    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "$Label failed with exit code $LASTEXITCODE."
    }
}

function Get-VSInstallPath {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vswhere) {
        $path = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
        if ($LASTEXITCODE -eq 0 -and $path) {
            return $path.Trim()
        }
    }
    return $null
}

function Enter-VSDevShellIfAvailable {
    $vsPath = Get-VSInstallPath
    if (-not $vsPath) {
        return $false
    }

    $module = Join-Path $vsPath "Common7\Tools\Microsoft.VisualStudio.DevShell.dll"
    if (-not (Test-Path $module)) {
        return $false
    }

    Import-Module $module
    Enter-VsDevShell -VsInstallPath $vsPath -SkipAutomaticLocation -DevCmdArguments "-arch=x64 -host_arch=x64" | Out-Null
    return $true
}

function Install-VSBuildTools {
    if (-not (Test-Command "winget")) {
        throw "winget was not found. Install Visual Studio 2022 Build Tools manually, then rerun this script."
    }

    Write-Step "Installing Visual Studio 2022 Build Tools components"
    winget install --id Microsoft.VisualStudio.2022.BuildTools --source winget --accept-package-agreements --accept-source-agreements --override "--wait --quiet --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.CMake.Project --add Microsoft.VisualStudio.Component.VC.Llvm.Clang --includeRecommended"
}

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

    return $null
}

if (-not (Test-Command "git")) {
    throw "git was not found in PATH. Install Git for Windows first."
}

$Conda = Resolve-CondaExe $CondaExe
if (-not $Conda) {
    throw "conda was not found. Open Anaconda PowerShell Prompt, install Miniconda/Anaconda, or pass -CondaExe C:\path\to\conda.exe."
}

Invoke-Checked "Initializing git submodules" {
    git submodule update --init --recursive
}

$envListText = (& $Conda env list) -join [Environment]::NewLine
if ($envListText -notmatch "(^|\s)$([regex]::Escape($EnvName))\s") {
    Invoke-Checked "Creating conda environment $EnvName with Python $PythonVersion" {
        & $Conda create -y -n $EnvName "python=$PythonVersion" pip cmake ninja
    }
} else {
    Invoke-Checked "Updating existing conda environment $EnvName with required base packages" {
        & $Conda install -y -n $EnvName "python=$PythonVersion" pip cmake ninja
    }
}

Invoke-Checked "Upgrading pip in $EnvName" {
    & $Conda run -n $EnvName python -m pip install --upgrade pip setuptools wheel
}

Invoke-Checked "Installing BitNet Python requirements" {
    & $Conda run -n $EnvName python -m pip install -r requirements.txt
}

if (-not $SkipModelDownload) {
    Invoke-Checked "Downloading GGUF model from Hugging Face" {
        & $Conda run -n $EnvName huggingface-cli download $ModelRepo --local-dir $ModelDir
    }
}

if (-not $SkipBuild) {
    $setupArgs = @("setup_env.py", "-md", $ModelDir, "-q", $QuantType)
    if ($UsePretuned) {
        $setupArgs += "-p"
    }

    $vsReady = Enter-VSDevShellIfAvailable
    if (-not $vsReady -and $InstallBuildTools) {
        Install-VSBuildTools
        $vsReady = Enter-VSDevShellIfAvailable
    }

    if (-not $vsReady) {
        throw "Visual Studio C++ build tools were not found. Install VS 2022 Build Tools with C++ CMake tools and Clang, or rerun with -InstallBuildTools."
    }

    if (-not (Test-Command "clang")) {
        throw "clang was not found after entering the Visual Studio developer shell. Add the VS C++ Clang component and rerun."
    }

    Invoke-Checked "Checking CMake inside $EnvName" {
        & $Conda run -n $EnvName cmake --version
    }

    if (-not $NoCleanBuild) {
        Invoke-Checked "Cleaning old CMake build directory" {
            $buildPath = Join-Path $RepoRoot "build"
            $resolvedRepo = (Resolve-Path $RepoRoot).Path
            if (Test-Path $buildPath) {
                $resolvedBuild = (Resolve-Path $buildPath).Path
                if (-not $resolvedBuild.StartsWith($resolvedRepo, [System.StringComparison]::OrdinalIgnoreCase)) {
                    throw "Refusing to remove build directory outside repo: $resolvedBuild"
                }
                Remove-Item -LiteralPath $resolvedBuild -Recurse -Force
            }
        }
    }

    if ($SkipModelDownload) {
        Invoke-Checked "Building bitnet.cpp for Windows CPU without preparing a model" {
            & $Conda run -n $EnvName python @setupArgs --skip-model-prepare
        }
    } else {
        Invoke-Checked "Building bitnet.cpp for Windows CPU with downloaded model" {
            & $Conda run -n $EnvName python @setupArgs
        }
    }
}

if (-not $SkipModelDownload) {
    Invoke-Checked "Verifying model file" {
        if (-not (Test-Path (Join-Path $ModelDir "ggml-model-$QuantType.gguf"))) {
            throw "Expected model file was not found: $ModelDir/ggml-model-$QuantType.gguf"
        }
    }
} elseif (-not $SkipBuild) {
    Write-Host ""
    Write-Host "Build finished. Model download was skipped, so download/copy a GGUF model before running inference." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Done. Try:" -ForegroundColor Green
Write-Host "conda activate $EnvName"
Write-Host "python run_inference.py -m $ModelDir/ggml-model-$QuantType.gguf -p `"You are a helpful assistant.`" -cnv -t 4 -n 128"
