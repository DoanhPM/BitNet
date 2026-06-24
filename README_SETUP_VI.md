# Setup BitNet CPU trên Windows

Tài liệu này dành cho luồng chạy local không cần GPU. Lỗi bạn gặp:

```text
Could not open requirements file:
3rdparty/llama.cpp/requirements/requirements-convert_legacy_llama.txt
```

thường đến từ 2 nguyên nhân:

- Clone repo chưa kéo submodule `3rdparty/llama.cpp`.
- Tạo conda env bằng `conda create -n bitnet-cpp` nhưng không cài Python, khiến `pip` trỏ sang Python ngoài env.

## Yêu cầu máy

- Windows 10/11 x64.
- Git for Windows.
- Anaconda hoặc Miniconda.
- Visual Studio 2022 Build Tools, chọn các component:
  - Desktop development with C++.
  - C++ CMake tools for Windows.
  - C++ Clang Compiler for Windows.
- Script build bằng CMake + Ninja để tránh lỗi thiếu MSBuild `ClangCL` toolset trên một số máy.

Nếu muốn script thử cài Build Tools bằng `winget`, thêm flag `-InstallBuildTools`.

## Cài đặt một lệnh

Mở **Anaconda PowerShell Prompt** hoặc **Developer PowerShell for VS 2022**, vào thư mục repo:

```powershell
cd D:\prjAI\BitNet
powershell -ExecutionPolicy Bypass -File .\scripts\setup-bitnet-windows-cpu.ps1
```

Script sẽ tự làm các bước:

- Kéo submodule `llama.cpp`.
- Tạo env `bitnet-cpp` với Python 3.9.
- Cài requirements bằng đúng Python trong env.
- Kiểm tra Visual Studio/Clang/CMake.
- Build CPU.
- Tải model GGUF `microsoft/BitNet-b1.58-2B-4T-gguf`.

Nếu chưa muốn tải model lớn, chạy:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup-bitnet-windows-cpu.ps1 -SkipModelDownload
```

Nếu muốn dùng kernel preset cho các model có sẵn trong `preset_kernels`, thêm `-UsePretuned`. Với model mặc định `microsoft/BitNet-b1.58-2B-4T-gguf`, không bật `-UsePretuned` vì repo hiện không có thư mục preset riêng cho model này.

Nếu máy mới chưa có Visual Studio Build Tools:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\setup-bitnet-windows-cpu.ps1 -InstallBuildTools
```

Sau khi cài Build Tools, có thể cần đóng/mở lại PowerShell rồi chạy lại script.

## Chạy inference

Cách 1, chạy qua helper:

```powershell
.\scripts\run-bitnet-windows-cpu.ps1 -Prompt "Bạn là trợ lý AI chạy local trên CPU." -Conversation -Threads 4 -Tokens 128
```

Cách 2, chạy trực tiếp:

```powershell
conda activate bitnet-cpp
python run_inference.py -m models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf -p "Bạn là trợ lý AI chạy local trên CPU." -cnv -t 4 -n 128
```

## Chạy trên máy khác

Trên máy mới:

```powershell
git clone --recursive https://github.com/microsoft/BitNet.git
cd BitNet
```

Nếu bạn copy thư mục dự án hiện tại sang máy khác thay vì clone mới, chạy:

```powershell
git submodule update --init --recursive
powershell -ExecutionPolicy Bypass -File .\scripts\setup-bitnet-windows-cpu.ps1
```

Nếu muốn mang theo model đã tải, copy cả thư mục:

```text
models\BitNet-b1.58-2B-4T
```

rồi chạy setup với `-SkipModelDownload`.

## Lệnh thủ công nếu không dùng script

```powershell
git submodule update --init --recursive
conda create -y -n bitnet-cpp python=3.9 pip cmake ninja
conda activate bitnet-cpp
python -m pip install --upgrade pip setuptools wheel
python -m pip install -r requirements.txt
huggingface-cli download microsoft/BitNet-b1.58-2B-4T-gguf --local-dir models/BitNet-b1.58-2B-4T
python setup_env.py -md models/BitNet-b1.58-2B-4T -q i2_s
python run_inference.py -m models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf -p "Hello from BitNet CPU" -cnv
```

Với model khác có thư mục trong `preset_kernels`, có thể thêm `-p` để dùng kernel preset:

```powershell
python setup_env.py -md models/bitnet_b1_58-3B -q tl2 -p
```

## Gỡ lỗi nhanh

Kiểm tra `pip` có đúng env không:

```powershell
conda activate bitnet-cpp
where python
python -m pip --version
```

Đường dẫn đúng nên nằm trong:

```text
C:\Users\<you>\anaconda3\envs\bitnet-cpp
```

Nếu `cmake` hoặc `clang` không nhận:

```powershell
clang --version
cmake --version
```

Hãy mở bằng **Developer PowerShell for VS 2022** hoặc cài thêm component C++/Clang của Visual Studio rồi chạy lại script.
