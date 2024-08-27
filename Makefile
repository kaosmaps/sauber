PACKAGE_NAME := sauber
GITHUB_ORG := kaosmaps
PYTHON_VERSION := 3.12.3
SUBPACKAGES := start

.PHONY: all clean scaffold create-files update-pyproject create-repos create-submodules init-parent-repo setup-env install-deps setup-hooks update-submodules setup-github test run-cli

all: clean scaffold create-files update-pyproject create-repos remove-submodules init-parent-repo create-submodules setup-env install-deps setup-hooks update-submodules setup-github


clean:
	@echo "Cleaning up..."
	rm -f poetry.lock
	rm -rf .venv

scaffold:
	@echo "Scaffolding project structure..."
	mkdir -p src/$(PACKAGE_NAME)/{core,services,cli,api} tests docs notebooks scripts data logs .github/workflows
	touch src/$(PACKAGE_NAME)/__init__.py src/$(PACKAGE_NAME)/{core,services,cli,api}/__init__.py tests/__init__.py docs/index.md notebooks/development.ipynb scripts/setup_project.sh .github/workflows/ci_cd.yml

define PYPROJECT_CONTENT
[tool.poetry]
name = "sauber"
version = "0.0.1"
description = "A Python package with submodules"
authors = ["Your Name <you@example.com>"]

[tool.poetry.dependencies]
python = "^3.12.3"
fastapi = "^0.112.0"
uvicorn = "^0.30.5"
click = "^8.1.7"
python-dotenv-vault = "^0.6.4"
pydantic = "^2.8.2"

[tool.poetry.group.dev.dependencies]
pytest = "^8.3.2"
ruff = "^0.5.7"
isort = "^5.13.2"
mypy = "^1.11.1"
pre-commit = "^3.7.0"

[build-system]
requires = ["poetry-core>=1.0.0"]
build-backend = "poetry.core.masonry.api"

[tool.poetry.scripts]
sauber = "src.sauber.cli:main"

[tool.pytest.ini_options]
testpaths = ["tests"]

[tool.ruff]
line-length = 88
target-version = "py312"

[tool.isort]
profile = "black"
line_length = 88

[tool.mypy]
python_version = "3.12"
strict = true
endef
export PYPROJECT_CONTENT

define PRECOMMIT_CONTENT
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
  - repo: https://github.com/pycqa/isort
    rev: 5.13.2
    hooks:
      - id: isort
  - repo: https://github.com/charliermarsh/ruff-pre-commit
    rev: v0.5.7
    hooks:
      - id: ruff
endef
export PRECOMMIT_CONTENT

define GITIGNORE_CONTENT
# Python
__pycache__/
*.py[cod]
*.so

# Virtual environments
.venv/
venv/
ENV/

# Poetry
poetry.lock

# Dotenv
.env
.env.*
!.env.vault

# IDEs
.vscode/
.idea/

# OS files
.DS_Store
Thumbs.db

# Logs
*.log

# Testing
.pytest_cache/
.coverage
htmlcov/

# Build
dist/
build/
*.egg-info/

# Jupyter Notebooks
.ipynb_checkpoints
endef
export GITIGNORE_CONTENT

define INIT_CONTENT
from .core import demo_function
from .services import MainService

__all__ = ['demo_function', 'MainService']
endef
export INIT_CONTENT

define CORE_CONTENT
def demo_function():
    return 'Hello from $(PACKAGE_NAME) core!'
endef
export CORE_CONTENT

define SERVICES_CONTENT
class MainService:
    def main_function(self):
        return 'Hello from $(PACKAGE_NAME) service!'
endef
export SERVICES_CONTENT

define CLI_CONTENT
import click

from .services import MainService

@click.group()
def cli():
    pass

@cli.command()
def main():
    service = MainService()
    click.echo(service.main_function())

if __name__ == "__main__":
    cli()
endef
export CLI_CONTENT

define API_CONTENT
from fastapi import FastAPI

from .services import MainService

app = FastAPI()

@app.get("/")
def root():
    service = MainService()
    return {"message": service.main_function()}
endef
export API_CONTENT

create-files:
	@echo "Creating configuration files..."
	@echo "$${PYPROJECT_CONTENT}" > pyproject.toml
	@echo "$${PRECOMMIT_CONTENT}" > .pre-commit-config.yaml
	@echo "$${GITIGNORE_CONTENT}" > .gitignore
	@echo "# $(PACKAGE_NAME)\n\nA Python package with submodules" > README.md
	@echo "# LICENSE content here" > LICENSE
	@echo "$${INIT_CONTENT}" > src/$(PACKAGE_NAME)/__init__.py
	@echo "$${CORE_CONTENT}" > src/$(PACKAGE_NAME)/core/__init__.py
	@echo "$${SERVICES_CONTENT}" > src/$(PACKAGE_NAME)/services/__init__.py
	@echo "$${CLI_CONTENT}" > src/$(PACKAGE_NAME)/cli/__init__.py
	@echo "$${API_CONTENT}" > src/$(PACKAGE_NAME)/api/__init__.py

update-pyproject:
	@echo "Updating pyproject.toml..."
	@echo "$${PYPROJECT_CONTENT}" > pyproject.toml

create-repos:
	@echo "Creating GitHub repositories if they don't exist..."
	@if ! gh repo view $(GITHUB_ORG)/$(PACKAGE_NAME) >/dev/null 2>&1; then \
		gh repo create $(GITHUB_ORG)/$(PACKAGE_NAME) --public || echo "Failed to create $(GITHUB_ORG)/$(PACKAGE_NAME). Continuing..."; \
	else \
		echo "Repository $(GITHUB_ORG)/$(PACKAGE_NAME) already exists. Skipping..."; \
	fi
	@for subpackage in $(SUBPACKAGES); do \
		if ! gh repo view $(GITHUB_ORG)/$(PACKAGE_NAME)-$$subpackage >/dev/null 2>&1; then \
			gh repo create $(GITHUB_ORG)/$(PACKAGE_NAME)-$$subpackage --public || echo "Failed to create $(GITHUB_ORG)/$(PACKAGE_NAME)-$$subpackage. Continuing..."; \
		else \
			echo "Repository $(GITHUB_ORG)/$(PACKAGE_NAME)-$$subpackage already exists. Skipping..."; \
		fi; \
	done

init-parent-repo:
	@if [ -z "$(shell git rev-parse --verify HEAD 2>/dev/null)" ]; then \
		git add . && \
		git commit -m "Initial commit" || true; \
	fi

remove-submodules:
	@echo "Removing submodules..."
	@for subpackage in $(SUBPACKAGES); do \
		git submodule deinit -f src/$(PACKAGE_NAME)/$$subpackage 2>/dev/null || true; \
		git rm -f src/$(PACKAGE_NAME)/$$subpackage 2>/dev/null || true; \
		rm -rf .git/modules/src/$(PACKAGE_NAME)/$$subpackage 2>/dev/null || true; \
		rm -rf src/$(PACKAGE_NAME)/$$subpackage 2>/dev/null || true; \
	done

# create-submodules: init-parent-repo
# 	@echo "Initializing git repository if not exists..."
# 	-git init
# 	@echo "Adding submodules..."
# 	@for subpackage in $(SUBPACKAGES); do \
# 		if [ ! -d "src/$(PACKAGE_NAME)/$$subpackage" ]; then \
# 			git submodule add -f https://github.com/$(GITHUB_ORG)/$(PACKAGE_NAME)-$$subpackage.git src/$(PACKAGE_NAME)/$$subpackage || echo "Failed to add submodule $(PACKAGE_NAME)-$$subpackage. Continuing..."; \
# 		else \
# 			echo "Submodule $(PACKAGE_NAME)-$$subpackage already exists. Skipping..."; \
# 		fi; \
# 	done
# 	@git submodule update --init --recursive

create-submodules: remove-submodules
	@echo "Adding submodules..."
	@for subpackage in $(SUBPACKAGES); do \
		git submodule add -f https://github.com/$(GITHUB_ORG)/$(PACKAGE_NAME)-$$subpackage.git src/$(PACKAGE_NAME)/$$subpackage || echo "Failed to add submodule $(PACKAGE_NAME)-$$subpackage. Continuing..."; \
	done
	@git submodule update --init --recursive

setup-env:
	@echo "Setting up Python environment..."
	@if command -v pyenv >/dev/null 2>&1; then \
		pyenv local $(PYTHON_VERSION) || echo "Failed to set local Python version. Continuing..."; \
	else \
		echo "pyenv not found. Skipping Python version setup."; \
	fi
	poetry config virtualenvs.in-project true
	@if [ ! -f pyproject.toml ]; then \
		poetry init -n; \
	else \
		echo "pyproject.toml already exists. Updating dependencies..."; \
		poetry update; \
	fi

install-deps:
	@echo "Installing dependencies..."
	poetry install --no-root
	poetry add fastapi uvicorn click python-dotenv-vault pydantic
	poetry add --group dev pytest ruff isort mypy pre-commit

setup-github:
	@echo "Setting up GitHub remote..."
	-git init
	-git add .
	-git commit -m "Initial commit" || true
	-poetry run pre-commit run --all-files
	-git add .
	-git commit -m "Apply pre-commit hooks" || true
	-git branch -M main
	-git remote remove origin || true
	-git remote add origin https://github.com/$(GITHUB_ORG)/$(PACKAGE_NAME).git
	@echo "GitHub remote set up. You can now push with: git push -u origin main"

setup-hooks:
	@echo "Setting up pre-commit hooks..."
	poetry run pre-commit install

update-submodules:
	@echo "Updating submodules..."
	git submodule update --init --recursive

test:
	poetry run pytest

run-cli:
	poetry run python -m src.$(PACKAGE_NAME).cli
