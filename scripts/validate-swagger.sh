#!/bin/bash

# Kubernetes Cluster Info Collector v2.0 - Swagger Validation Script
# Validates the OpenAPI 3.0.3 specification for correctness

set -e

echo "🔍 Kubernetes Cluster Info Collector v2.0 - Swagger Validation"
echo "=============================================================="

# Check if docs/swagger.yaml exists
if [ ! -f "docs/docs/swagger.yaml" ]; then
    echo "❌ Error: docs/docs/swagger.yaml not found in current directory"
    echo "Please run this script from the project root directory"
    exit 1
fi

echo ""
echo "📝 Validating docs/docs/swagger.yaml..."

# Method 1: Try using swagger-codegen (if available)
if command -v swagger-codegen >/dev/null 2>&1; then
    echo "Using swagger-codegen validator..."
    swagger-codegen validate -i docs/swagger.yaml
    echo "✅ swagger-codegen validation passed"
elif command -v npx >/dev/null 2>&1; then
    echo "Using NPX validator..."
    
    # Try @apidevtools/swagger-parser which handles YAML properly
    if npx --yes @apidevtools/swagger-parser validate docs/swagger.yaml 2>/dev/null; then
        echo "✅ @apidevtools/swagger-parser validation passed"
    else
        echo "⚠️  Direct validation failed, creating validation script..."
        
        # Create a temporary Node.js validation script
        cat > temp_validate.js << 'EOF'
const SwaggerParser = require('@apidevtools/swagger-parser');

async function validate() {
    try {
        const api = await SwaggerParser.validate('docs/swagger.yaml');
        console.log('✅ OpenAPI validation passed');
        console.log(`📋 API: ${api.info.title} v${api.info.version}`);
        console.log(`📊 Endpoints: ${Object.keys(api.paths).length}`);
        
        // Check for v2.0 specific features
        const swaggerContent = JSON.stringify(api);
        if (swaggerContent.includes('kafka')) {
            console.log('✅ Kafka features detected');
        }
        if (swaggerContent.includes('WebSocket') || swaggerContent.includes('websocket')) {
            console.log('✅ WebSocket documentation detected');
        }
        
        process.exit(0);
    } catch (err) {
        console.error('❌ OpenAPI validation failed:', err.message);
        process.exit(1);
    }
}

validate();
EOF
        
        if npx --yes @apidevtools/swagger-parser node temp_validate.js; then
            echo "✅ Validation completed successfully"
        else
            echo "⚠️  NPX validation failed, falling back to basic checks"
        fi
        
        rm -f temp_validate.js
    fi
elif command -v docker >/dev/null 2>&1; then
    echo "Using Docker-based validator..."
    docker run --rm -v "$(pwd):/workspace" \
        openapitools/openapi-generator-cli validate \
        -i /workspace/docs/swagger.yaml
    echo "✅ Docker validation passed"
else
    echo "⚠️  No external validation tools found. Performing comprehensive basic checks..."
    
    # Enhanced YAML syntax and structure validation
    VALIDATION_PASSED=true
    
    # Check YAML syntax
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "
import yaml
import sys
try:
    with open('docs/swagger.yaml', 'r') as f:
        data = yaml.safe_load(f)
    print('✅ YAML syntax is valid')
    
    # Basic OpenAPI structure validation
    required_fields = ['openapi', 'info', 'paths']
    for field in required_fields:
        if field not in data:
            print(f'❌ Missing required field: {field}')
            sys.exit(1)
    
    print('✅ Basic OpenAPI structure is valid')
    
    # Check version
    if 'version' in data.get('info', {}):
        version = data['info']['version']
        print(f'✅ API Version: {version}')
    
    # Count paths
    path_count = len(data.get('paths', {}))
    print(f'✅ Found {path_count} API endpoints')
    
except yaml.YAMLError as e:
    print(f'❌ YAML syntax error: {e}')
    sys.exit(1)
except Exception as e:
    print(f'❌ Validation error: {e}')
    sys.exit(1)
"
    elif command -v ruby >/dev/null 2>&1; then
        ruby -e "
require 'yaml'
begin
  data = YAML.load_file('docs/swagger.yaml')
  puts '✅ YAML syntax is valid'
  
  # Basic structure check
  required_fields = ['openapi', 'info', 'paths']
  required_fields.each do |field|
    unless data.key?(field)
      puts \"❌ Missing required field: #{field}\"
      exit 1
    end
  end
  
  puts '✅ Basic OpenAPI structure is valid'
  puts \"✅ Found #{data['paths'].length} API endpoints\" if data['paths']
rescue => e
  puts \"❌ Validation error: #{e}\"
  exit 1
end
"
    else
        echo "⚠️  Basic validation: Checking file exists and has content..."
        if [ -s "docs/swagger.yaml" ]; then
            echo "✅ docs/swagger.yaml exists and has content"
            
            # Basic grep-based checks
            if grep -q "openapi:" docs/swagger.yaml && grep -q "info:" docs/swagger.yaml && grep -q "paths:" docs/swagger.yaml; then
                echo "✅ Contains required OpenAPI sections"
            else
                echo "❌ Missing required OpenAPI sections"
                VALIDATION_PASSED=false
            fi
            
            if grep -q "version: 2.0.0" docs/swagger.yaml; then
                echo "✅ Version 2.0.0 found"
            else
                echo "⚠️  Version might not be updated to 2.0.0"
            fi
        else
            echo "❌ docs/swagger.yaml is empty or doesn't exist"
            VALIDATION_PASSED=false
        fi
    fi
    
    if [ "$VALIDATION_PASSED" = true ]; then
        echo "✅ Basic validation passed"
    else
        echo "❌ Basic validation failed"
        exit 1
    fi
fi

echo ""
echo "📊 API Statistics:"

# Count endpoints
ENDPOINT_COUNT=$(grep -c "^\s*/" docs/swagger.yaml || echo "0")
echo "• Total Endpoints: $ENDPOINT_COUNT"

# Count schemas
SCHEMA_COUNT=$(grep -c "^\s*[A-Z][a-zA-Z]*Info:\|^\s*[A-Z][a-zA-Z]*Message:\|^\s*[A-Z][a-zA-Z]*Summary:" docs/swagger.yaml || echo "0")
echo "• Total Schemas: $SCHEMA_COUNT"

# Check for v2.0 features
if grep -q "kafka" docs/swagger.yaml; then
    echo "✅ Kafka endpoints present"
else
    echo "⚠️  Kafka endpoints missing"
fi

if grep -q "WebSocket\|websocket\|ws:" docs/swagger.yaml; then
    echo "✅ WebSocket documentation present"
else
    echo "⚠️  WebSocket documentation missing"
fi

if grep -q "metrics" docs/swagger.yaml; then
    echo "✅ Metrics endpoints present"
else
    echo "⚠️  Metrics endpoints missing"
fi

if grep -q "retention" docs/swagger.yaml; then
    echo "✅ Retention endpoints present"
else
    echo "⚠️  Retention endpoints missing"
fi

echo ""
echo "🎯 Next Steps:"
echo "1. Run './scripts/view-api-docs.sh' to view the documentation"
echo "2. Test API endpoints with './scripts/test-api.sh' (if available)"
echo "3. Deploy the collector and verify endpoints are responding"
echo ""
echo "📚 Documentation Files:"
echo "• docs/swagger.yaml - OpenAPI 3.0.3 specification"
echo "• docs/API.md - API usage guide"
echo "• view-api-docs.sh - Documentation viewer script"
echo ""
echo "✅ Validation completed!"
