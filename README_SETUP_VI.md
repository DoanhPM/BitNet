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

Chế độ chat một lượt: model trả lời xong rồi thoát.

```powershell
python run_inference.py -m models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf -p "Hãy giải thích BitNet bằng tiếng Việt ngắn gọn." -cnv -t 4 -n 256
```

Chế độ trò chuyện liên tục trong terminal: dùng thêm `-i`. Khi vào màn hình chat, gõ câu hỏi rồi Enter. Thoát bằng `Ctrl+C`.

```powershell
python run_inference.py -m models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf -p "You are a helpful Vietnamese assistant." -cnv -i -t 4 -n 256
```

Các tham số hay chỉnh:

- `-t`: số CPU threads. Với i5-10210U có 4 core/8 threads, thử `-t 4` trước; nếu máy vẫn mượt có thể thử `-t 6` hoặc `-t 8`.
- `-n`: số token tối đa model sinh ra. Tăng số này thì câu trả lời dài hơn nhưng chạy lâu hơn.
- `-c`: context size. Mặc định `2048`; giảm xuống `1024` để tiết kiệm RAM/tăng tốc, tăng lên `4096` nếu cần prompt dài.
- `-temp`: temperature. `0.2-0.5` ổn định hơn, `0.7-0.9` sáng tạo hơn.
- `--no-warmup`: bỏ bước warmup ban đầu để lần chạy test nhanh hơn.

Ví dụ cấu hình nhẹ cho máy không GPU:

```powershell
python run_inference.py -m models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf -p "Tóm tắt lợi ích của mô hình 1-bit." -cnv -t 4 -n 128 -c 1024 --no-warmup
```

## Chạy server local

Server phù hợp khi muốn gọi từ app khác qua HTTP.

```powershell
conda activate bitnet-cpp
python run_inference_server.py -m models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf -t 4 -c 2048 --host 127.0.0.1 --port 8080
```

Sau khi server chạy, mở:

```text
http://127.0.0.1:8080
```

## Đánh giá tốc độ

Đánh giá tốc độ bằng `llama-bench` qua script có sẵn:

```powershell
conda activate bitnet-cpp
python utils/e2e_benchmark.py -m models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf -p 256 -n 128 -t 4
```

Ý nghĩa các số chính:

- `pp` hoặc prompt processing: tốc độ xử lý prompt đầu vào. Cao hơn là tốt hơn.
- `tg` hoặc text generation: tốc độ sinh token. Cao hơn là tốt hơn.
- `tok/s`: tokens per second. Đây là số dễ so sánh nhất khi benchmark tốc độ.
- `ms/tok`: milliseconds per token. Thấp hơn là tốt hơn.

Nên benchmark nhiều cấu hình threads:

```powershell
python utils/e2e_benchmark.py -m models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf -p 256 -n 128 -t 2
python utils/e2e_benchmark.py -m models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf -p 256 -n 128 -t 4
python utils/e2e_benchmark.py -m models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf -p 256 -n 128 -t 8
```

Chọn cấu hình có `tg tok/s` cao nhưng máy vẫn không quá nóng/đơ. Với laptop i5-10210U, `-t 4` thường là điểm bắt đầu hợp lý.

## Đánh giá chất lượng

Có 2 kiểu đánh giá nên dùng:

- Đánh giá cảm nhận: hỏi cùng một bộ câu hỏi tiếng Việt/tiếng Anh, so sánh độ đúng, độ mạch lạc, khả năng làm theo yêu cầu.
- Đánh giá perplexity: đo độ khớp của model với tập văn bản. Perplexity thấp hơn thường tốt hơn, nhưng chỉ nên so sánh trên cùng dataset và cùng cấu hình.

Chuẩn bị dataset perplexity theo cấu trúc:

```text
data
└── vi_sample
    └── test.txt
```

Ví dụ tạo nhanh dataset nhỏ:

```powershell
New-Item -ItemType Directory -Force data\vi_sample
Set-Content -Encoding UTF8 data\vi_sample\test.txt "Trí tuệ nhân tạo đang thay đổi cách con người làm việc, học tập và sáng tạo."
```

Chạy perplexity nhanh:

```powershell
python utils/test_perplexity.py -m models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf -d data -t 4 -c 512 --quick
```

Kết quả được lưu vào:

```text
perplexity_results
```

Cách đọc:

- `perplexity` hoặc `PPL`: thấp hơn là tốt hơn.
- `time_seconds`: thời gian chạy test, thấp hơn là nhanh hơn.
- `status`: `success` nghĩa là test đọc được kết quả.

Lưu ý: dataset quá ngắn chỉ dùng để kiểm tra pipeline. Muốn số PPL có ý nghĩa, dùng file `test.txt` dài hơn, cùng domain bạn quan tâm, ví dụ tài liệu tiếng Việt, code, hội thoại, hoặc dữ liệu nội bộ đã được phép dùng.

## Đọc log inference

Khi chạy inference, cuối output thường có các dòng:

```text
prompt eval time = ...
eval time = ...
total time = ...
```

Ý nghĩa:

- `prompt eval time`: thời gian xử lý prompt đầu vào.
- `eval time`: thời gian sinh token trả lời.
- `tokens per second`: càng cao càng nhanh.
- `load time`: thời gian load model từ ổ đĩa vào RAM.

Các warning sau là bình thường với bản CPU-only:

```text
warning: not compiled with GPU offload support
warning: see main README.md for information on enabling GPU BLAS support
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
