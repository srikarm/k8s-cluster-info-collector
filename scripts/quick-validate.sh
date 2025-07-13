#!/bin/bash

# Simple Swagger validation using basic checks
echo "🔍 Quick Swagger Validation for v2.0"
echo "===================================="

if [ ! -f "docs/swagger.yaml" ]; then
    echo "❌ docs/swagger.yaml not found"
    exit 1
fi

echo "✅ docs/swagger.yaml found"

# Check for v2.0 indicators
if grep -q "version: 2.0.0" docs/swagger.yaml; then
    echo "✅ Version 2.0.0 detected"
else
    echo "⚠️  Version 2.0.0 not found"
fi

if grep -q "kafka" docs/swagger.yaml; then
    echo "✅ Kafka endpoints present"
else
    echo "⚠️  Kafka endpoints missing"
fi

if grep -q "/metrics" docs/swagger.yaml; then
    echo "✅ Metrics endpoint present"
else
    echo "⚠️  Metrics endpoint missing"
fi

if grep -q "/ws" docs/swagger.yaml; then
    echo "✅ WebSocket endpoint present"
else
    echo "⚠️  WebSocket endpoint missing"
fi

if grep -q "services:" docs/swagger.yaml; then
    echo "✅ Services endpoints present"
else
    echo "⚠️  Services endpoints missing"
fi

if grep -q "ingresses:" docs/swagger.yaml; then
    echo "✅ Ingresses endpoints present"
else
    echo "⚠️  Ingresses endpoints missing"
fi

echo ""
echo "📊 Endpoint count: $(grep -c "^\s*/" docs/swagger.yaml)"
echo "📊 Schema count: $(grep -c "^\s*[A-Z][a-zA-Z]*:" docs/swagger.yaml)"

echo ""
echo "✅ Basic validation completed!"
echo "💡 Run './scripts/view-api-docs.sh' to view the full documentation"
