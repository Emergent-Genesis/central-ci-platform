FROM ollama/ollama:latest

# Bake mistral:7b-instruct weights into the image at build time.
# ollama serve must be running for the pull to work — start it, pull, then stop.
# Model files persist in /root/.ollama/models as a layer in the image.
RUN /bin/bash -c '\
    /bin/ollama serve & \
    sleep 15 && \
    /bin/ollama pull mistral:7b-instruct && \
    kill %1 2>/dev/null; exit 0'

EXPOSE 11434
ENTRYPOINT ["/bin/ollama", "serve"]
