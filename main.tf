terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

provider "coder" {}
provider "docker" {}

# ─── Workspace Owner Info ───────────────────────────────────
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

# ─── Parameters (Interactive UI in Coder Dashboard) ─────────
data "coder_parameter" "project_name" {
  name         = "project_name"
  display_name = "Project Name"
  description  = "Name of your heart disease AI project"
  type         = "string"
  default      = "Heart-Disease-AI"
  order        = 1
}

data "coder_parameter" "python_version" {
  name         = "python_version"
  display_name = "Python Version"
  description  = "Select Python version for your workspace"
  type         = "string"
  default      = "3.11"
  order        = 2

  option {
    name  = "Python 3.11 (Recommended)"
    value = "3.11"
  }
  option {
    name  = "Python 3.10"
    value = "3.10"
  }
}

data "coder_parameter" "install_gpu" {
  name         = "install_gpu"
  display_name = "Enable GPU Support?"
  description  = "Enable GPU for faster model training (if available)"
  type         = "bool"
  default      = false
  order        = 3
}

# ─── Startup Script ─────────────────────────────────────────
resource "coder_agent" "main" {
  arch           = "amd64"
  os             = "linux"
  startup_script = <<-SCRIPT
    #!/bin/bash
    set -e

    echo "🚀 Setting up Heart Disease AI Workspace..."

    # Install Python dependencies
    pip install --quiet \
      jupyter \
      notebook \
      scikit-learn \
      pandas \
      numpy \
      matplotlib \
      seaborn \
      shap \
      ipywidgets

    echo "✅ Dependencies installed!"

    # Download the notebook if not exists
    if [ ! -f ~/heart_disease_ai.ipynb ]; then
      echo "📥 Setting up notebook..."
      cat > ~/heart_disease_ai.ipynb << 'NBEOF'
{
 "nbformat": 4,
 "nbformat_minor": 0,
 "metadata": {
   "kernelspec": {"display_name": "Python 3", "language": "python", "name": "python3"},
   "language_info": {"name": "python", "version": "3.11.0"}
 },
 "cells": [
   {
     "cell_type": "markdown",
     "metadata": {},
     "source": ["# ❤️ Heart Disease Risk Predictor\n### Byte2Beat Hackathon | Built by Abhi Raj\n**Model:** Random Forest | **Accuracy:** 87.5% | **Dataset:** 918 patients"]
   },
   {
     "cell_type": "code",
     "metadata": {},
     "source": ["!pip install shap scikit-learn pandas numpy matplotlib seaborn -q\nprint('✅ Ready!')"],
     "execution_count": null, "outputs": []
   }
 ]
}
NBEOF
      echo "✅ Notebook ready!"
    fi

    # Start Jupyter
    echo "🌐 Starting Jupyter Notebook..."
    jupyter notebook \
      --no-browser \
      --ip=0.0.0.0 \
      --port=8888 \
      --NotebookApp.token='' \
      --NotebookApp.password='' \
      --notebook-dir=~ &

    echo "✅ Jupyter is running on port 8888!"
    echo "🎯 Heart Disease AI workspace is ready!"
  SCRIPT
}

# ─── Jupyter App (shows in Coder dashboard) ─────────────────
resource "coder_app" "jupyter" {
  agent_id     = coder_agent.main.id
  slug         = "jupyter"
  display_name = "❤️ Heart Disease AI — Jupyter"
  url          = "http://localhost:8888"
  icon         = "https://upload.wikimedia.org/wikipedia/commons/3/38/Jupyter_logo.svg"
  subdomain    = true

  healthcheck {
    url       = "http://localhost:8888/api"
    interval  = 5
    threshold = 10
  }
}

# ─── Docker Container ────────────────────────────────────────
resource "docker_image" "python" {
  name = "python:${data.coder_parameter.python_version.value}-slim"
}

resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count
  image = docker_image.python.image_id
  name  = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"

  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
    "PROJECT_NAME=${data.coder_parameter.project_name.value}",
  ]

  command = [
    "sh", "-c",
    "pip install coder-agent --quiet && exec coder-agent"
  ]

  volumes {
    container_path = "/home/user"
    volume_name    = docker_volume.home.name
    read_only      = false
  }
}

resource "docker_volume" "home" {
  name = "coder-${data.coder_workspace_owner.me.name}-home"
}
