import os
import sys
import signal
import platform
import argparse
import subprocess
import tempfile

def format_chat_prompt(system_prompt, user_prompt):
    return (
        "<|start_header_id|>system<|end_header_id|>\n\n"
        f"{system_prompt}<|eot_id|>"
        "<|start_header_id|>user<|end_header_id|>\n\n"
        f"{user_prompt}<|eot_id|>"
        "<|start_header_id|>assistant<|end_header_id|>\n\n"
    )

def run_command(command, shell=False):
    """Run a system command and ensure it succeeds."""
    try:
        subprocess.run(command, shell=shell, check=True)
    except subprocess.CalledProcessError as e:
        print(f"Error occurred while running command: {e}")
        sys.exit(1)

def run_inference():
    build_dir = "build"
    if platform.system() == "Windows":
        main_path = os.path.join(build_dir, "bin", "Release", "llama-cli.exe")
        if not os.path.exists(main_path):
            main_path = os.path.join(build_dir, "bin", "llama-cli.exe")
    else:
        main_path = os.path.join(build_dir, "bin", "llama-cli")

    prompt = args.prompt
    if args.conversation and args.interactive:
        prompt = args.system_prompt
    elif args.conversation:
        prompt = format_chat_prompt(args.system_prompt, args.prompt)

    prompt_file = tempfile.NamedTemporaryFile("w", encoding="utf-8", suffix=".txt", delete=False)
    try:
        prompt_file.write(prompt)
        prompt_file.close()

        command = [
            f'{main_path}',
            '-m', args.model,
            '-n', str(args.n_predict),
            '-t', str(args.threads),
            '-f', prompt_file.name,
            '-ngl', '0',
            '-c', str(args.ctx_size),
            '--temp', str(args.temperature),
            "-b", str(args.batch_size),
        ]
        if not args.interactive:
            command.append("--no-display-prompt")
        if args.conversation and args.interactive:
            command.append("-cnv")
        if args.no_warmup:
            command.append("--no-warmup")
        run_command(command)
    finally:
        try:
            os.unlink(prompt_file.name)
        except OSError:
            pass

def signal_handler(sig, frame):
    print("Ctrl+C pressed, exiting...")
    sys.exit(0)

if __name__ == "__main__":
    signal.signal(signal.SIGINT, signal_handler)
    # Usage: python run_inference.py -p "Microsoft Corporation is an American multinational corporation and technology company headquartered in Redmond, Washington."
    parser = argparse.ArgumentParser(description='Run inference')
    parser.add_argument("-m", "--model", type=str, help="Path to model file", required=False, default="models/bitnet_b1_58-3B/ggml-model-i2_s.gguf")
    parser.add_argument("-n", "--n-predict", type=int, help="Number of tokens to predict when generating text", required=False, default=128)
    parser.add_argument("-p", "--prompt", type=str, help="Prompt to generate text from", required=True)
    parser.add_argument("-t", "--threads", type=int, help="Number of threads to use", required=False, default=2)
    parser.add_argument("-c", "--ctx-size", type=int, help="Size of the prompt context", required=False, default=2048)
    parser.add_argument("-temp", "--temperature", type=float, help="Temperature, a hyperparameter that controls the randomness of the generated text", required=False, default=0.8)
    parser.add_argument("-b", "--batch-size", type=int, help="Batch size to use during prompt processing", required=False, default=32)
    parser.add_argument("--system-prompt", type=str, help="System prompt used when --conversation is enabled", required=False, default="You are a helpful assistant.")
    parser.add_argument("--no-warmup", action='store_true', help="Disable the initial warmup run")
    parser.add_argument("-i", "--interactive", action='store_true', help="Use llama-cli interactive conversation mode. Requires --conversation")
    parser.add_argument("-cnv", "--conversation", action='store_true', help="Format the prompt as a one-shot chat message and exit")

    args = parser.parse_args()
    run_inference()
