import requests
import numpy as np

url = "https://localhost/api/v1/embedding/validate"

def validate_embedding(embedding: np.ndarray):
    if embedding is None:
        raise ValueError("Embedding is None.")

    embedding_list = embedding.tolist()

    data = {
        "vector": embedding_list
    }
    response = requests.post(url, json=data, verify=False, cert=('./certs/client.crt', './certs/client.key'))

    if response.status_code == 200:
        return True, response.json()
    else:
        return False, response.text
