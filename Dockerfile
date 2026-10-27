# The Semurg memory tools for an MCP client that starts a local program (stdio).
# Your Semurg node runs separately (see README.md); this container carries each MCP message to it and its answer back.
# With no node reachable it still lists the tools, and every call says that no node answered at SEMURG_URL.
FROM python:3.12-slim
RUN pip install --no-cache-dir semurg==0.1.6
ENV SEMURG_URL=http://127.0.0.1:4000
CMD ["semurg", "mcp"]
