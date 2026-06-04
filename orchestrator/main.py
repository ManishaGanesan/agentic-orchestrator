from uais_client import call_llm


def test_llm():

    messages = [
        {
            "role": "system",
            "content": "You are a helpful assistant. Reply in one short sentence."
        },
        {
            "role": "user", 
            "content": "Hi, what is a prime number?"
        }
    ]

    response = call_llm(messages)

    print("\n LLM RESPONSE:\n")
    print(response)


if __name__ == "__main__":
    test_llm()
