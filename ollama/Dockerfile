ARG BASE_VERSION=0.7.0
FROM ollama/ollama:${BASE_VERSION}

COPY pull_models.sh /pull_models.sh
RUN chmod +x /pull_models.sh

ENV OLLAMA_HOST=0.0.0.0 \
    OLLAMA_KEEP_ALIVE=5m \
    OLLAMA_NUM_PARALLEL=4

CMD ["/pull_models.sh"]
