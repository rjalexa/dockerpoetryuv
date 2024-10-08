# Stage 1: Base image with Python and system dependencies
FROM python:3.11.10-bullseye AS python-base

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    PIP_DEFAULT_TIMEOUT=100 \
    POETRY_HOME="/opt/poetry" \
    POETRY_VIRTUALENVS_IN_PROJECT=true \
    POETRY_NO_INTERACTION=1 \
    PROJECT_DIR="/app" \
    VENV_PATH="/app/.venv"

# Add Poetry and venv to the PATH
ENV PATH="$POETRY_HOME/bin:$VENV_PATH/bin:$PATH"

# Install system dependencies
RUN buildDeps="build-essential" \
    && apt-get update \
    && apt-get install --no-install-recommends -y \
    curl \
    vim \
    netcat \
    && apt-get install -y --no-install-recommends $buildDeps \
    && rm -rf /var/lib/apt/lists/*

# Stage 2: Install Poetry and dependencies
FROM python-base AS builder

# Set Poetry and uv versions
ENV POETRY_VERSION=1.8.3
ENV UV_VERSION=0.2.17

# Install Poetry and uv
RUN curl -sSL https://install.python-poetry.org | python3 - && chmod a+x /opt/poetry/bin/poetry
RUN poetry self add poetry-plugin-export
RUN pip install uv==$UV_VERSION

# Set working directory
WORKDIR $PROJECT_DIR

# Copy project files
COPY pyproject.toml poetry.lock ./

# Create venv and install dependencies
RUN python -m venv $VENV_PATH \
    && . $VENV_PATH/bin/activate \
    && poetry export -f requirements.txt --output requirements.txt \
    && uv pip install -r requirements.txt

# Stage 3: Final production image
FROM python-base AS production

# Copy virtual environment from builder stage
COPY --from=builder $VENV_PATH $VENV_PATH

# Set working directory
WORKDIR $PROJECT_DIR

# Copy the rest of the application
COPY app/main.py .

# Set up non-root user
RUN groupadd -r isagog && useradd -r -g isagog isagog

# Change ownership of the app directory to isagog
RUN chown -R isagog:isagog $PROJECT_DIR

EXPOSE 8000

# Switch to non-root user
USER isagog

# Set the entrypoint to activate the virtual environment
ENTRYPOINT ["/bin/bash", "-c", "source $VENV_PATH/bin/activate && exec $0 $@"]