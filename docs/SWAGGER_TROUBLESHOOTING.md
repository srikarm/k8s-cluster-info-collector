# Swagger Documentation Troubleshooting Guide

## Common Issues and Solutions

### 1. NPX Swagger-UI-Serve YAML Syntax Error

**Problem:**
```
Using NPX + Swagger UI Serve...
/Users/.../swagger.yaml:1
openapi: 3.0.3
            ^^
SyntaxError: Unexpected number
```

**Cause:** The `swagger-ui-serve` package expects JSON format, not YAML.

**Solutions:**

#### Option A: Use Docker (Recommended)
```bash
../scripts/view-api-docs.sh
# Select option 1: Docker + Swagger UI
```

#### Option B: Generate Static HTML
```bash
../scripts/view-api-docs.sh
# Select option 6: Generate Static HTML (No Dependencies)
```

#### Option C: Online Editor
```bash
../scripts/view-api-docs.sh
# Select option 3: Online Swagger Editor
```

#### Option D: Convert YAML to JSON (Manual)
```bash
# Convert YAML to JSON
npx js-yaml swagger.yaml > swagger.json

# Serve the JSON file
npx swagger-ui-serve swagger.json
```

### 2. NPX Package Installation Issues

**Problem:** `npm ERR! could not determine executable to run`

**Solutions:**

#### Clear NPX Cache
```bash
npx --yes @apidevtools/swagger-parser validate swagger.yaml
```

#### Use Alternative Tools
```bash
# Use Docker validation
docker run --rm -v "$(pwd):/workspace" \
  openapitools/openapi-generator-cli validate \
  -i /workspace/swagger.yaml

# Or use Python (if available)
python3 -c "import yaml; yaml.safe_load(open('swagger.yaml'))"
```

### 3. Validation Script Hanging

**Problem:** Script appears to hang during NPX validation.

**Solutions:**

#### Force Basic Validation
```bash
# Rename npx temporarily to force basic validation
which npx > /tmp/npx_path
sudo mv $(which npx) $(which npx).backup
./validate-swagger.sh
sudo mv $(which npx).backup $(which npx)
```

#### Use Manual Validation
```bash
# Quick structure check
grep -E "^openapi:|^info:|^paths:" swagger.yaml

# Version check
grep "version: 2.0.0" swagger.yaml

# Feature check
grep -c "kafka\|WebSocket\|metrics\|retention" swagger.yaml
```

### 4. Best Practices for API Documentation

#### Recommended Viewing Methods (in order)

1. **Docker + Swagger UI** - Full interactive experience
2. **Static HTML Generation** - Works offline, no dependencies
3. **VS Code Extension** - Good for development
4. **Online Editor** - Universal fallback

#### Development Workflow

```bash
# 1. Make changes to swagger.yaml
vim swagger.yaml

# 2. Validate changes
./validate-swagger.sh

# 3. Generate documentation
../scripts/view-api-docs.sh
# Select option 6 for quick offline viewing

# 4. Test API endpoints (when running)
../scripts/test-api.sh
```

### 5. Alternative Tools

If the provided scripts don't work, try these alternatives:

#### Swagger Editor Desktop
```bash
# Install Swagger Editor desktop app
# https://swagger.io/tools/swagger-editor/

# Or use VS Code with extensions
code --install-extension 42Crunch.vscode-openapi
code swagger.yaml
```

#### Online Tools
- [Swagger Editor](https://editor.swagger.io/)
- [Redoc](https://redocly.github.io/redoc/)
- [SwaggerHub](https://app.swaggerhub.com/)

#### Command Line Tools
```bash
# Install swagger-codegen (if available)
brew install swagger-codegen  # macOS
apt-get install swagger-codegen  # Ubuntu

# Validate
swagger-codegen validate -i swagger.yaml
```

## Quick Fixes Summary

| Issue | Quick Fix |
|-------|-----------|
| NPX YAML Syntax Error | Use option 6 (Static HTML) |
| NPX hanging | Use option 1 (Docker) or basic validation |
| No external tools | Use option 5 (Terminal summary) |
| Development setup | Use VS Code with OpenAPI extension |
| Production docs | Generate static HTML and serve via web server |

## Version Information

- **Swagger/OpenAPI Version:** 3.0.3
- **API Version:** 2.0.0
- **Features:** 9 Kubernetes resource types, Kafka integration, WebSocket streaming

For more help, see:
- `docs/API.md` - API usage guide
- `docs/USAGE_EXAMPLES.md` - Comprehensive examples
- `README.md` - Main project documentation
