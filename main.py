# from uais_client import call_llm
from dataset_builder.input_processor import InputProcessor
import json
import os
# def test_llm():

#     messages = [
#         {
#             "role": "system",
#             "content": "You are a helpful assistant. Reply in one short sentence."
#         },
#         {
#             "role": "user", 
#             "content": "Hi, what is a prime number?"
#         }
#     ]

#     response = call_llm(messages)

#     print("\n LLM RESPONSE:\n")
#     print(response)

def test_inputprocessor():

    INPUT_DIR = "input_excels/"

    result = processor.process_folder(INPUT_DIR)

    print(json.dumps(result, indent=2, default=str))

    output_file = os.path.join(INPUT_DIR, "output.json")
    with open(output_file, "w") as f:
        json.dump(result, f, indent=2, default=str)

    print(f"Output saved to: {output_file}")



processor = InputProcessor()

if __name__ == "__main__":
    #test_llm()
    test_inputprocessor()




