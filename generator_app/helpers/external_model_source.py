from enum import Enum
import os
from typing import Optional
# Imports que funcionan tanto localmente (generator_app) como en Docker (/app)
from pathlib import Path

if Path(__file__).parent.parent.parent.name == "generator_app":
    # Ejecutándose localmente
    from generator_app.schemas.supported_models import SupportedModels
else:
    # Ejecutándose en Docker (código en /app)
    from app.schemas.supported_models import SupportedModels
import openai
import anthropic
import os
from dotenv import load_dotenv


class ExternalModel:
    def __init__(self, model_name: SupportedModels):
        print('aca3')
        print('model_name:', model_name)
        self.model_name = model_name
        load_dotenv()
        self.openAIKey = os.getenv("OPENAI_API_KEY")
        self.anthropicKey = os.getenv("ANTHROPIC_API_KEY")
        print(self.anthropicKey)
        self.system_prompt = os.getenv("SYSTEM_PROMPT")
        self.user_prefix = os.getenv("USER_PREFIX")


    def generate(self, prompt: str) -> str:
        print('aca4')

        """Generate response using the specified external model."""
        print('model_name:', self.model_name)
        print('SupportedModels.CLAUDE_SONNET_4.value:', SupportedModels.CLAUDE_SONNET_4.value)
        if self.model_name == SupportedModels.CLAUDE_SONNET_4.value:
            print('aca5')

            return self._call_anthropic_api(prompt)
        elif self.model_name == SupportedModels.CHATGPT_4.value:
            print('aca6')

            return self._call_openai_api(prompt)
        else:
            raise ValueError(f"Unsupported model: {self.model_name}")

    def _call_anthropic_api(self, prompt: str) -> str:
        """Call Anthropic Claude API."""
        try:
            client = anthropic.Anthropic(api_key=self.anthropicKey)
            
            message = client.messages.create(
                model=self.model_name,
                max_tokens=1000,
                temperature=0.7,
                system=self.system_prompt,
                messages=[
                    {"role": "user", "content": self.user_prefix + prompt}
                ]
            )
            
            return message.content[0].text
        except Exception as e:
            raise Exception(f"Error calling Anthropic API: {str(e)}")

    def _call_openai_api(self, prompt: str) -> str:
        """Call OpenAI GPT API."""
        try:
            client = openai.OpenAI(api_key=self.openAIKey)
            
            result = client.responses.create(
                model=self.model_name,
                input= self.system_prompt + self.user_prefix + prompt,
                reasoning={ "effort": "low" },
                text={ "verbosity": "low" },
            )
            output_text = result.output_text

            return output_text
    
        except Exception as e:
            raise Exception(f"Error calling OpenAI API: {str(e)}")