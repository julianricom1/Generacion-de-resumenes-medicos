import os, json
from pathlib import Path
import torch
from transformers import AutoTokenizer, AutoModelForCausalLM
from peft import PeftModel
from huggingface_hub import login
from dotenv import load_dotenv
import threading


DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

SYSTEM_PROMPT = (
    "You simplify clinical trial protocol text into a plain-language summary for the general public. "
    "Keep to 6–8th grade readability, avoid diagnoses and speculation, no hallucinations, "
    "and preserve key facts (objective, population, interventions, outcomes, timelines, safety)."
)
USER_PREFIX = "Using the following clinical trial protocol text as input, create a plain language summary.\n\n"

MODEL_DIR = os.getenv(
    "MODEL_DIR",
    "generacion/ollama/outputs/meta-llama__Llama-3.2-3B-Instruct-FKGD9_Sliding_Window/final",
)

GEN_CFG = dict(
    max_new_tokens=int(os.getenv("MAX_NEW_TOKENS", "512")),
    do_sample=True,
    temperature=float(os.getenv("TEMPERATURE", "0.2")),
    top_p=0.9,
    no_repeat_ngram_size=0,
    repetition_penalty=1.015,
)

class FinnedTunnedModel:
    """
    Singleton class for fine-tuned model management.
    Ensures only one instance of the model is loaded in memory.
    """
    _instance = None
    _lock = threading.Lock()
    _initialized = False

    def __new__(cls):
        """
        Create a new instance only if one doesn't exist.
        Thread-safe singleton implementation.
        """
        if cls._instance is None:
            with cls._lock:
                # Double-check locking pattern
                if cls._instance is None:
                    cls._instance = super(FinnedTunnedModel, cls).__new__(cls)
        return cls._instance

    def __init__(self):
        """
        Initialize the model only once, even if __init__ is called multiple times.
        """
        if not self._initialized:
            with self._lock:
                if not self._initialized:
                    # Add authentication before loading the model
                    load_dotenv()
                    hf_token = os.getenv("HUGGINGFACE_HUB_TOKEN")
                    if hf_token:
                        login(token=hf_token)

                    print('hf_token')
                    print(hf_token)
                    model, tokenizer, EOS_ID = self.load_model_and_tokenizer(MODEL_DIR, DEVICE)
                    self.model = model
                    self.tokenizer = tokenizer
                    self.EOS_ID = EOS_ID
                    FinnedTunnedModel._initialized = True
                    print("FinnedTunnedModel singleton initialized successfully")

    def is_initialized(self):
        """
        Check if the model has been initialized.
        
        Returns:
            bool: True if the model is loaded and ready to use
        """
        return self._initialized and hasattr(self, 'model') and self.model is not None

    def load_model_and_tokenizer(self, model_dir: str, device: str = DEVICE):
        """
        Load the model and tokenizer. This method is called only once during initialization.
        """
        print('Loading model from:', model_dir)
        hf_token = os.getenv("HUGGINGFACE_HUB_TOKEN")
        model_dir = str(Path(model_dir).resolve())
        cfg_path = Path(model_dir) / "adapter_config.json"
        if not cfg_path.exists():
            raise FileNotFoundError(f"No existe {cfg_path}")

        adapter_cfg = json.loads(Path(cfg_path).read_text(encoding="utf-8"))
        base = adapter_cfg.get("base_model_name_or_path")
        if not base:
            raise ValueError("adapter_config.json no contiene 'base_model_name_or_path'.")

        print('model_dir')
        print(model_dir)
        tok = AutoTokenizer.from_pretrained(model_dir, token=hf_token, use_fast=True, trust_remote_code=True)
        if tok.pad_token is None:
            tok.pad_token = tok.eos_token
        tok.padding_side = "left"
        print('model_dir2')
        print(base)

        base_model = AutoModelForCausalLM.from_pretrained(
            base,
            torch_dtype=torch.float16 if device.startswith("cuda") else torch.float32,
            trust_remote_code=True
        ).to(device)
        print('model_dir3')

        base_model.resize_token_embeddings(len(tok))
        print('model_dir4')

        print('type of base_model:', type(base_model))
        model = PeftModel.from_pretrained(base_model, model_dir, is_trainable=False, local_files_only=True)
        print('model_dir5')

        ##model.eval()
        model.config.pad_token_id = tok.pad_token_id
        print('model_dir6')

        eos_id = None
        try:
            eid = tok.convert_tokens_to_ids("<|sentence_end|>")
            if eid is not None and eid != tok.unk_token_id:
                eos_id = eid
        except Exception:
            pass

        return model, tok, eos_id

    def build_prompt(self, src: str) -> str:
        """
        Build a prompt for the model using the chat template.
        
        Args:
            src (str): Source text to create a summary for
            
        Returns:
            str: Formatted prompt ready for the model
        """
        if not self.is_initialized():
            raise RuntimeError("Model not initialized. Call FinnedTunnedModel() first.")
            
        return self.tokenizer.apply_chat_template(
            [{"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user",   "content": USER_PREFIX + str(src)}],
            tokenize=False, add_generation_prompt=True
        )

    def generate(self, text: str) -> str:
        """
        Generate a summary for the given text.
        
        Args:
            text (str): Input text to summarize
            
        Returns:
            str: Generated summary
            
        Raises:
            RuntimeError: If the model is not initialized
        """
        if not self.is_initialized():
            raise RuntimeError("Model not initialized. Call FinnedTunnedModel() first.")
            
        print('Generating summary for text of length:', len(text))
        cfg = GEN_CFG.copy()
        if self.EOS_ID is not None:
            cfg["eos_token_id"] = self.EOS_ID
        cfg["pad_token_id"] = self.tokenizer.pad_token_id

        print('Generating prompt...')

        prompt = self.build_prompt(text)
        print('Prompt generated. Length:', len(prompt))
        print('Prompt generated :', prompt)
        inputs = self.tokenizer(prompt, return_tensors="pt", padding=True, truncation=True).to(DEVICE)
        gen = self.model.generate(**inputs, **cfg)
        print('Generation completed.')
        cut = inputs["input_ids"].shape[1]
        summary = self.tokenizer.decode(gen[0, cut:], skip_special_tokens=True).strip()
        return summary

        """
        Cleanup method to ensure proper resource disposal.
        """
        if hasattr(self, 'model') and self.model is not None:
            # Move model to CPU to free GPU memory
            self.model.cpu()
            del self.model
            print("FinnedTunnedModel resources cleaned up")