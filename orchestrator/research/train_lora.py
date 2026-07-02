"""
orchestrator/research/train_lora.py
"""
import os
import json
import sys
import subprocess
from pathlib import Path
import torch
from datasets import Dataset
from transformers import AutoModelForCausalLM, AutoTokenizer, TrainingArguments, Trainer
from peft import LoraConfig, get_peft_model, TaskType, PeftModel

ROOT_DIR = Path(__file__).resolve().parents[2]

def load_historical_canonical_dataset():
    """
    Dynamically builds your training dataset using your real historical canonical
    JSON payloads and matching validated target SQL migration blocks.
    """
    json_path = ROOT_DIR / "output_json" / "canonical_output.json"
    sql_path = ROOT_DIR / "orchestrator" / "knowledge" / "V191100-v191101_RateManager.sql"
    
    if not json_path.exists() or not sql_path.exists():
        print("[WARNING] Historical source pairs missing. Falling back to structured baseline map.")
        return Dataset.from_list([{
            "text": "<|user|>\nGenerate T-SQL updates for State ID: MR, Pricer Class: PhysicianPro, Action: UPDATE.\n<|end|>\n<|assistant|>\nDELETE FROM [dbo].[LUT_PricerTypeAPRPro_StateProcedure] WHERE [LUTSID] = 82;<|end|>"
        }])

    with open(json_path, "r", encoding="utf-8") as f:
        canonical_data = json.load(f)
    
    state_procedures = canonical_data.get("state_procedures", [])
    target_sql = sql_path.read_text(encoding="utf-8", errors="ignore")
    sql_lines = target_sql.splitlines()
    clean_sql_block = "\n".join([l for l in sql_lines if "LUT_PricerTypeAPRPro" in l or "DELETE" in l])

    instruction = f"Generate T-SQL database update sequences matching this payload structure:\n{json.dumps(state_procedures)}"
    formatted_prompt = f"<|user|>\n{instruction}<|end|>\n<|assistant|>\n{clean_sql_block}<|end|>"
    
    return Dataset.from_list([{"text": formatted_prompt}])

def run_lora_alignment():
    model_id = "microsoft/Phi-3-mini-4k-instruct"
    tokenizer = AutoTokenizer.from_pretrained(model_id, trust_remote_code=False) # ◄--- CHANGE TO FALSE    tokenizer.pad_token = tokenizer.eos_token
    
    peft_config = LoraConfig(
        r=8,
        lora_alpha=16,
        target_modules=["qkv_proj", "o_proj"],
        lora_dropout=0.05,
        bias="none",
        task_type=TaskType.CAUSAL_LM
    )
    
    print("[RUNNING] Loading base floating-point parameters...")
    model = AutoModelForCausalLM.from_pretrained(
        model_id,
        trust_remote_code=False,       # ◄--- CHANGE TO FALSE TO BYPASS BROKEN HF CACHE SCRIPT
        torch_dtype=torch.bfloat16,
        device_map="auto",
        attn_implementation="eager"    # ◄--- FORCE STABLE NATIVE EAGER ATTENTION
    )
    peft_model = get_peft_model(model, peft_config)
    
    dataset = load_historical_canonical_dataset()
    dataset = dataset.map(lambda x: tokenizer(x["text"], truncation=True, max_length=2048), batched=True)
    
    trainer = Trainer(
        model=peft_model,
        args=TrainingArguments(
            output_dir=str(ROOT_DIR / "models" / "phi3-lora-adapter"),
            per_device_train_batch_size=1,
            gradient_accumulation_steps=4,
            learning_rate=2e-4,
            num_train_epochs=5,
            bf16=True,             # ◄--- CHANGE FROM fp16=True TO bf16=True FOR MPS
            logging_steps=1,
            save_strategy="no",
            use_cpu=False          # Ensure it doesn't default-fallback to CPU
        ),
        train_dataset=dataset,
        data_collator=lambda data: {
            "input_ids": torch.stack([torch.tensor(f["input_ids"]) for f in data]),
            "attention_mask": torch.stack([torch.tensor(f["attention_mask"]) for f in data]),
            "labels": torch.stack([torch.tensor(f["input_ids"]) for f in data]),
        }
    )
    
    print("[RUNNING] Fine-tuning model weights using historical canonical mappings...")
    trainer.train()
    
    # Save adapter matrix parameters
    adapter_path = ROOT_DIR / "models" / "phi3-final-lora"
    peft_model.save_pretrained(str(adapter_path))
    print(f"[SUCCESS] Custom schema alignment complete. Adapter saved to {adapter_path}")

    # ================= AUTOMATED INFRASTRUCTURE WIRING BLOCK =================
    print("\n[WIRING] Initiating neural parameter weight export...")
    
    # 1. Merge weights back into single baseline model architecture configuration
    base_model_reload = AutoModelForCausalLM.from_pretrained(
        model_id, torch_dtype=torch.float16, device_map="cpu", trust_remote_code=True
    )
    merged_model = PeftModel.from_pretrained(base_model_reload, str(adapter_path))
    merged_model = merged_model.merge_and_unload()
    
    merged_hf_path = ROOT_DIR / "models" / "phi3-merged-hf"
    merged_model.save_pretrained(str(merged_hf_path))
    tokenizer.save_pretrained(str(merged_hf_path))
    print(f"[SUCCESS] Merged weights exported to HF format at: {merged_hf_path}")

    # 4. Programmatically compile the output into the final GGUF inference destination folder path
    target_gguf_dir = ROOT_DIR / "models"
    target_gguf_dir.mkdir(parents=True, exist_ok=True)
    output_gguf_file = target_gguf_dir / "Phi-3-mini-4k-instruct-q4.gguf"

    print("[WIRING] Invoking llama.cpp compilation script tools to construct binary...")
    
    # Comprehensive check for llama.cpp conversion script variations
    possible_scripts = [
        ROOT_DIR / "llama.cpp" / "convert_hf_to_gguf.py",
        ROOT_DIR / "llama.cpp" / "convert.py",
        ROOT_DIR / "llama.cpp" / "models" / "convert_hf_to_gguf.py"
    ]
    
    convert_script = None
    for script in possible_scripts:
        if script.exists():
            convert_script = script
            break

    if not convert_script:
        print("\n[ERR] llama.cpp repository tools not found in root directory.")
        print("Please execute: git clone https://github.com/ggerganov/llama.cpp")
        return

    quant_command = [
        sys.executable,
        str(convert_script),
        str(merged_hf_path),
        "--outfile", str(output_gguf_file),
        "--outtype", "f16"
    ]
    
    try:
        subprocess.run(quant_command, check=True)
        print(f"\n[PIPELINE READY] Successfully compiled fine-tuned weights! Binary located at: {output_gguf_file}")
    except Exception as conversion_error:
        print(f"\n[CRITICAL BUILD ERROR] Quantitative compilation script failed: {str(conversion_error)}")
if __name__ == "__main__":
    run_lora_alignment()

