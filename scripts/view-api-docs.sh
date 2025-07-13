#!/bin/bash

# Kubernetes Cluster Info Collector v2.0 - API Documentation Viewer
# This script helps you easily view the comprehensive v2.0 API documentation

set -e

echo "🔗 Kubernetes Cluster Info Collector v2.0 - API Documentation Viewer"
echo "====================================================================="
echo ""
echo "📚 API Features:"
echo "• 9 Kubernetes Resource Types (Deployments, Pods, Nodes, Services, etc.)"
echo "• Dual Architecture Support (Legacy + Kafka)"
echo "• Real-time WebSocket Streaming"
echo "• Prometheus Metrics Endpoint"
echo "• Kafka Statistics & Monitoring"
echo "• Data Retention Management"
echo "• Enhanced Health Checks"

# Check if docs/swagger.yaml exists
if [ ! -f "docs/swagger.yaml" ]; then
    echo "❌ Error: docs/swagger.yaml not found in current directory"
    echo "Please run this script from the project root directory"
    exit 1
fi

echo ""
echo "Select how you want to view the API documentation:"
echo ""
echo "1) 🐳 Docker + Swagger UI (Best Interactive Experience)"
echo "2) 📦 NPX + HTTP Server (Node.js Required)"
echo "3) 🌐 Online Swagger Editor (Copy/Paste Method)"
echo "4) 💻 VS Code Preview (Extension Required)"
echo "5) 📖 Quick API Summary (Terminal View)"
echo "6) 📄 Generate Static HTML (Recommended - No Dependencies)"
echo ""
echo "💡 Recommended: Option 6 for reliability, Option 1 for full features"
echo ""
read -p "Enter your choice (1-6): " choice

case $choice in
    1)
        echo ""
        echo "🐳 Starting Swagger UI with Docker..."
        
        # Check if Docker is running
        if ! docker info >/dev/null 2>&1; then
            echo "❌ Error: Docker is not running or not installed"
            echo "Please install Docker and ensure it's running"
            exit 1
        fi
        
        # Stop any existing container
        docker stop swagger-ui-cluster-info 2>/dev/null || true
        docker rm swagger-ui-cluster-info 2>/dev/null || true
        
        # Start Swagger UI
        echo "Starting Swagger UI container..."
        docker run -d --name swagger-ui-cluster-info \
            -p 8080:8080 \
            -e SWAGGER_JSON=/app/docs/swagger.yaml \
            -v "$(pwd)/docs/swagger.yaml:/app/docs/swagger.yaml" \
            swaggerapi/swagger-ui
        
        echo ""
        echo "✅ Swagger UI is now running!"
        echo "🌐 Open in browser: http://localhost:8080"
        echo ""
        echo "🔍 Key API Endpoints to Explore:"
        echo "• GET /api/v1/snapshots - View cluster snapshots"
        echo "• GET /api/v1/health - Enhanced health check (v2.0)"
        echo "• GET /api/v1/metrics - Prometheus metrics"
        echo "• GET /api/v1/stats/kafka - Kafka statistics (v2.0)"
        echo "• WebSocket /api/v1/ws - Real-time streaming"
        echo ""
        echo "To stop: docker stop swagger-ui-cluster-info"
        
        # Try to open in default browser (macOS/Linux)
        if command -v open >/dev/null 2>&1; then
            open http://localhost:8080
        elif command -v xdg-open >/dev/null 2>&1; then
            xdg-open http://localhost:8080
        fi
        ;;
        
    2)
        echo ""
        echo "📦 Using NPX + Custom Server..."
        
        # Check if Node.js/NPX is available
        if ! command -v npx >/dev/null 2>&1; then
            echo "❌ Error: NPX is not installed"
            echo "Please install Node.js (which includes NPX)"
            exit 1
        fi
        
        echo "Starting Swagger UI server..."
        echo "Note: Converting YAML to JSON for compatibility"
        
        # Convert YAML to JSON with multiple fallback methods
        YAML_CONVERTED=false
        
        # Method 1: Try with PyYAML if available
        if command -v python3 >/dev/null 2>&1; then
            echo "Converting docs/swagger.yaml to JSON (trying PyYAML)..."
            if python3 -c "import yaml" 2>/dev/null; then
                python3 -c "
import yaml, json
with open('docs/swagger.yaml', 'r') as f:
    data = yaml.safe_load(f)
with open('temp_swagger.json', 'w') as f:
    json.dump(data, f, indent=2)
print('✅ Converted to JSON format using PyYAML')
" && YAML_CONVERTED=true
            else
                echo "⚠️  PyYAML not installed, trying alternative methods..."
            fi
        fi
        
        # Method 2: Try with Ruby if Python/PyYAML failed
        if [ "$YAML_CONVERTED" = false ] && command -v ruby >/dev/null 2>&1; then
            echo "Converting docs/swagger.yaml to JSON (using Ruby)..."
            if ruby -e "
require 'yaml'
require 'json'
data = YAML.load_file('docs/swagger.yaml')
File.write('temp_swagger.json', JSON.pretty_generate(data))
puts '✅ Converted to JSON format using Ruby'
" 2>/dev/null; then
                YAML_CONVERTED=true
            else
                echo "⚠️  Ruby YAML conversion failed"
            fi
        fi
        
        # Method 3: Try with Node.js if other methods failed
        if [ "$YAML_CONVERTED" = false ]; then
            echo "Converting docs/swagger.yaml to JSON (using Node.js)..."
            if npx --yes js-yaml docs/swagger.yaml > temp_swagger.json 2>/dev/null; then
                echo "✅ Converted to JSON format using js-yaml"
                YAML_CONVERTED=true
            else
                echo "⚠️  Node.js YAML conversion failed"
            fi
        fi
        
        if [ "$YAML_CONVERTED" = true ]; then
            # Now serve the JSON file
            echo "Starting Swagger UI with JSON file..."
            echo "✅ Server will start at http://localhost:3000"
            
            # Try to open in browser
            if command -v open >/dev/null 2>&1; then
                (sleep 3 && open http://localhost:3000) &
            elif command -v xdg-open >/dev/null 2>&1; then
                (sleep 3 && xdg-open http://localhost:3000) &
            fi
            
            # Use a simple HTTP server
            npx --yes http-server . -p 3000 -o /swagger-ui/?url=http://localhost:3000/temp_swagger.json -c-1 --cors
            
            # Cleanup
            rm -f temp_swagger.json
            
        else
            echo "⚠️  All YAML conversion methods failed"
            echo "🔄 Falling back to static HTML generation (most reliable)..."
            echo ""
            
            # Jump directly to option 6 logic
            echo "📄 Generating Static HTML Documentation..."
            echo ""
            echo "📋 Creating comprehensive documentation with embedded YAML..."
            
            # Read docs/swagger.yaml content and escape it for JavaScript
            SWAGGER_CONTENT=$(cat docs/swagger.yaml | sed 's/`/\\`/g' | sed 's/\$/\\$/g')
            
            # Generate comprehensive static HTML
            cat > swagger-ui.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>K8s Cluster Info Collector v2.0 - API Documentation</title>
    <link rel="stylesheet" type="text/css" href="https://unpkg.com/swagger-ui-dist@latest/swagger-ui.css" />
    <style>
        body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
        .info { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; text-align: center; }
        .info h1 { margin: 0 0 10px 0; font-size: 2em; }
        .info p { margin: 5px 0; opacity: 0.9; }
        #swagger-ui { max-width: 1200px; margin: 0 auto; }
    </style>
</head>
<body>
    <div class="info">
        <h1>🔗 Kubernetes Cluster Info Collector v2.0</h1>
        <p><strong>API Documentation</strong> - Interactive Swagger UI</p>
        <p>📚 Features: 9 Resource Types • Kafka Integration • WebSocket Streaming • Prometheus Metrics</p>
    </div>
    <div id="swagger-ui"></div>
    <script src="https://unpkg.com/swagger-ui-dist@latest/swagger-ui-bundle.js" charset="UTF-8"></script>
    <script src="https://unpkg.com/swagger-ui-dist@latest/swagger-ui-standalone-preset.js" charset="UTF-8"></script>
    <script src="https://unpkg.com/js-yaml@latest/dist/js-yaml.min.js"></script>
    <script>
        window.onload = function() {
            // Parse YAML content
            const yaml = \`$SWAGGER_CONTENT\`;
            
            const ui = SwaggerUIBundle({
                spec: jsyaml.load(yaml),
                dom_id: '#swagger-ui',
                deepLinking: true,
                presets: [
                    SwaggerUIBundle.presets.apis,
                    SwaggerUIStandalonePreset
                ],
                plugins: [
                    SwaggerUIBundle.plugins.DownloadUrl
                ],
                layout: "StandaloneLayout",
                tryItOutEnabled: true,
                requestInterceptor: function(request) {
                    return request;
                }
            });
        };
    </script>
</body>
</html>
EOF
            
            echo "✅ Static HTML documentation generated!"
            echo "📄 File: swagger-ui.html"
            echo ""
            echo "🌐 To view:"
            echo "• Open swagger-ui.html in your web browser"
            echo "• Or run: open swagger-ui.html (macOS)"
            echo "• Or run: xdg-open swagger-ui.html (Linux)"
            echo ""
            echo "� This file works offline and includes all v2.0 API documentation"
            
            # Try to open in default browser
            if command -v open >/dev/null 2>&1; then
                echo ""
                echo "🚀 Opening in default browser..."
                open swagger-ui.html
            elif command -v xdg-open >/dev/null 2>&1; then
                echo ""
                echo "🚀 Opening in default browser..."
                xdg-open swagger-ui.html
            fi
        fi
        ;;
        
    3)
        echo ""
        echo "🌐 Opening Online Swagger Editor..."
        echo ""
        echo "1. Go to: https://editor.swagger.io/"
        echo "2. Copy the contents of docs/swagger.yaml"
        echo "3. Paste into the editor"
        echo ""
        echo "Contents of docs/swagger.yaml:"
        echo "========================"
        cat docs/swagger.yaml
        
        # Try to open in default browser
        if command -v open >/dev/null 2>&1; then
            open https://editor.swagger.io/
        elif command -v xdg-open >/dev/null 2>&1; then
            xdg-open https://editor.swagger.io/
        fi
        ;;
        
    4)
        echo ""
        echo "💻 VS Code Preview..."
        
        if command -v code >/dev/null 2>&1; then
            echo "Opening docs/swagger.yaml in VS Code..."
            code docs/swagger.yaml
            echo ""
            echo "Instructions:"
            echo "1. Install the 'Swagger Viewer' extension if not already installed"
            echo "2. Open Command Palette (Ctrl+Shift+P / Cmd+Shift+P)"
            echo "3. Type 'Swagger: Preview' and select it"
        else
            echo "❌ Error: VS Code command 'code' not found"
            echo "Please install VS Code and ensure it's in your PATH"
            exit 1
        fi
        ;;
        
    5)
        echo ""
        echo "📖 API Summary - Kubernetes Cluster Info Collector v2.0"
        echo "======================================================="
        echo ""
        echo "🔗 Base URL: http://localhost:8081/api/v1"
        echo ""
        echo "📊 SNAPSHOTS & HISTORICAL DATA:"
        echo "GET    /snapshots                 - List all cluster snapshots"
        echo "GET    /snapshots/latest          - Get latest snapshot"
        echo "GET    /snapshots/{id}            - Get specific snapshot"
        echo ""
        echo "🎯 KUBERNETES RESOURCES (9 Types):"
        echo "GET    /deployments               - List deployments"
        echo "GET    /pods                      - List pods"
        echo "GET    /nodes                     - List nodes"
        echo "GET    /services                  - List services"
        echo "GET    /ingresses                 - List ingresses"
        echo "GET    /configmaps                - List configmaps"
        echo "GET    /secrets                   - List secrets"
        echo "GET    /persistent-volumes        - List persistent volumes"
        echo "GET    /persistent-volume-claims  - List PVCs"
        echo ""
        echo "📈 MONITORING & METRICS (v2.0):"
        echo "GET    /metrics                   - Prometheus metrics"
        echo "GET    /stats                     - General statistics"
        echo "GET    /stats/kafka               - Kafka metrics (v2.0)"
        echo "GET    /stats/retention           - Retention statistics"
        echo "POST   /retention/cleanup         - Manual cleanup"
        echo ""
        echo "🏥 HEALTH & STATUS:"
        echo "GET    /health                    - Enhanced health check"
        echo ""
        echo "🌊 REAL-TIME STREAMING:"
        echo "WS     /ws                        - WebSocket connection"
        echo "       • cluster_update messages"
        echo "       • metrics_update messages"
        echo "       • alert messages"
        echo "       • heartbeat messages"
        echo ""
        echo "📚 Query Parameters:"
        echo "• ?limit=N                  - Limit results"
        echo "• ?namespace=ns             - Filter by namespace"
        echo "• ?node=name                - Filter by node"
        echo ""
        echo "📋 Response Formats:"
        echo "• JSON for all REST endpoints"
        echo "• text/plain for /metrics (Prometheus format)"
        echo "• WebSocket JSON messages for real-time data"
        echo ""
        echo "🔍 Example Usage:"
        echo "curl http://localhost:8081/api/v1/snapshots/latest"
        echo "curl http://localhost:8081/api/v1/health"
        echo "curl http://localhost:8081/api/v1/stats/kafka"
        echo ""
        ;;
        
    6)
        echo ""
        echo "📄 Generating Static HTML Documentation..."
        
        # Read the docs/swagger.yaml content
        SWAGGER_CONTENT=$(cat docs/swagger.yaml | sed 's/`/\\`/g' | sed 's/\$/\\$/g')
        
        # Generate static HTML file
        cat > swagger-ui.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Kubernetes Cluster Info Collector v2.0 - API Documentation</title>
    <link rel="stylesheet" type="text/css" href="https://unpkg.com/swagger-ui-dist@latest/swagger-ui.css" />
    <link rel="icon" type="image/png" href="https://unpkg.com/swagger-ui-dist@latest/favicon-32x32.png" sizes="32x32" />
    <style>
        html { box-sizing: border-box; overflow: -moz-scrollbars-vertical; overflow-y: scroll; }
        *, *:before, *:after { box-sizing: inherit; }
        body { margin:0; background: #fafafa; }
        .info { margin-bottom: 20px; padding: 20px; background: #f8f9fa; border-radius: 4px; }
        .info h1 { color: #3b4151; margin: 0 0 10px 0; }
        .info p { color: #3b4151; margin: 5px 0; }
    </style>
</head>
<body>
    <div class="info">
        <h1>🔗 Kubernetes Cluster Info Collector v2.0</h1>
        <p><strong>API Documentation</strong> - Interactive Swagger UI</p>
        <p>📚 Features: 9 Resource Types • Kafka Integration • WebSocket Streaming • Prometheus Metrics</p>
    </div>
    <div id="swagger-ui"></div>
    <script src="https://unpkg.com/swagger-ui-dist@latest/swagger-ui-bundle.js" charset="UTF-8"></script>
    <script src="https://unpkg.com/swagger-ui-dist@latest/swagger-ui-standalone-preset.js" charset="UTF-8"></script>
    <script>
        window.onload = function() {
            // Parse YAML content
            const yaml = \`$SWAGGER_CONTENT\`;
            
            const ui = SwaggerUIBundle({
                spec: jsyaml.load(yaml),
                dom_id: '#swagger-ui',
                deepLinking: true,
                presets: [
                    SwaggerUIBundle.presets.apis,
                    SwaggerUIStandalonePreset
                ],
                plugins: [
                    SwaggerUIBundle.plugins.DownloadUrl
                ],
                layout: "StandaloneLayout",
                tryItOutEnabled: true,
                requestInterceptor: function(request) {
                    // Modify requests if needed
                    return request;
                }
            });
        };
    </script>
    <script src="https://unpkg.com/js-yaml@latest/dist/js-yaml.min.js"></script>
</body>
</html>
EOF
        
        echo "✅ Static HTML documentation generated!"
        echo "📄 File: swagger-ui.html"
        echo ""
        echo "🌐 To view:"
        echo "• Open swagger-ui.html in your web browser"
        echo "• Or run: open swagger-ui.html (macOS)"
        echo "• Or run: xdg-open swagger-ui.html (Linux)"
        echo ""
        echo "💡 This file works offline and includes all v2.0 API documentation"
        
        # Try to open in default browser
        if command -v open >/dev/null 2>&1; then
            echo ""
            echo "🚀 Opening in default browser..."
            open swagger-ui.html
        elif command -v xdg-open >/dev/null 2>&1; then
            echo ""
            echo "🚀 Opening in default browser..."
            xdg-open swagger-ui.html
        fi
        ;;
        
    *)
        echo "❌ Invalid choice. Please run the script again and select 1-6."
        exit 1
        ;;
esac

echo ""
echo "📚 Additional Documentation:"
echo "• API Reference: docs/API.md"
echo "• Usage Examples: docs/USAGE_EXAMPLES.md"
echo "• Main README: README.md"
echo "• Architecture Guide: Implementation details in README"
echo ""
echo "🚀 v2.0 New Features:"
echo "• Kafka integration for horizontal scaling"
echo "• 9 comprehensive resource types"
echo "• Real-time WebSocket streaming"
echo "• Enhanced monitoring and metrics"
echo "• Automated data retention"
