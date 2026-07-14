#!/usr/bin/env zsh

# Check if URL is provided
if [[ $# -eq 0 ]]; then
    echo "Error: Please provide a URL"
    echo "Usage: $0 <URL>"
    echo "Example: $0 http://192.168.115.169:80"
    echo "Example: $0 https://example.com:443"
    exit 1
fi

# Store the URL from command line argument
URL=$1

# Check if URL ends with slash and remove it for consistency
URL=${URL%/}

# Extract hostname/IP and port from URL
if [[ $URL =~ ^(https?://)?([^:/]+)(:([0-9]+))?(/.*)?$ ]]; then
    HOST=${match[2]}
    PORT=${match[4]:-80}  # Default to 80 if no port specified
    
    # Handle HTTPS default port
    if [[ $URL =~ ^https:// ]] && [[ -z $match[4] ]]; then
        PORT=443
    fi
else
    echo "Error: Invalid URL format"
    exit 1
fi

# Create output directory with host and port
OUTPUT_DIR="ffuf_${HOST}_${PORT}_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTPUT_DIR"

echo "=================================================="
echo "Starting ffuf scans against: $URL"
echo "Host: $HOST | Port: $PORT"
echo "Output directory: $OUTPUT_DIR"
echo "=================================================="

# Check if ffuf is installed
if ! command -v ffuf &> /dev/null; then
    echo "Error: ffuf is not installed or not in PATH"
    exit 1
fi

# Check if seclists is installed
if [[ ! -f "/usr/share/seclists/Discovery/Web-Content/common.txt" ]]; then
    echo "Warning: SecLists not found at /usr/share/seclists/"
    echo "You may need to install it or update the wordlist paths"
fi

echo "\n[1/3] Running common.txt scan..."
ffuf -w /usr/share/seclists/Discovery/Web-Content/common.txt \
     -u "$URL/FUZZ" \
     -o "$OUTPUT_DIR/${HOST}_${PORT}_common.txt" \
     -of csv \
     -c

echo "\n[2/3] Running raft-large-directories scan..."
ffuf -w /usr/share/seclists/Discovery/Web-Content/raft-large-directories.txt \
     -u "$URL/FUZZ" \
     -o "$OUTPUT_DIR/${HOST}_${PORT}_raft_directories.txt" \
     -of csv \
     -c

echo "\n[3/3] Running raft-large-files scan with extensions..."
ffuf -w /usr/share/seclists/Discovery/Web-Content/raft-large-files.txt \
     -e .html,.php,.log,.txt,.bak,.zip \
     -u "$URL/FUZZ" \
     -o "$OUTPUT_DIR/${HOST}_${PORT}_raft_files.txt" \
     -of csv \
     -c

echo "\n=================================================="
echo "All scans completed!"
echo "Results saved in: $OUTPUT_DIR"
echo "=================================================="

# Optional: Display summary of findings
echo "\nSummary of found directories/files for $HOST:$PORT:"
for file in "$OUTPUT_DIR"/*.txt; do
    if [[ -f "$file" ]]; then
        echo "\nResults from $(basename "$file"):"
        # Display only successful findings (status code 200, 201, 204, 301, 302, 307, 401, 403)
        grep -E ",(200|201|204|301|302|307|401|403|500),[0-9]+,.*" "$file" 2>/dev/null | while IFS= read -r line; do
            # Parse CSV line and display in readable format
            STATUS=$(echo "$line" | cut -d',' -f2)
            SIZE=$(echo "$line" | cut -d',' -f3)
            URL_PATH=$(echo "$line" | cut -d',' -f5)
            echo "  [Status: $STATUS] [Size: $SIZE] $URL_PATH"
        done | head -20
        if [[ $? -ne 0 ]]; then
            echo "  No interesting findings found"
        else
            echo "  (showing first 20 results - full results in file)"
        fi
    fi
done

# Create a simple HTML report
REPORT_FILE="$OUTPUT_DIR/report_${HOST}_${PORT}.html"
cat > "$REPORT_FILE" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>ffuf Scan Report - $HOST:$PORT</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        h1 { color: #333; }
        h2 { color: #666; margin-top: 30px; }
        table { border-collapse: collapse; width: 100%; background: white; }
        th { background: #4CAF50; color: white; padding: 10px; text-align: left; }
        td { padding: 8px; border-bottom: 1px solid #ddd; }
        tr:hover { background: #f5f5f5; }
        .status-200 { color: green; font-weight: bold; }
        .status-403 { color: orange; }
        .status-401 { color: orange; }
        .status-500 { color: red; }
        .summary { background: white; padding: 15px; margin-bottom: 20px; border-radius: 5px; }
    </style>
</head>
<body>
    <h1>ffuf Scan Report - $HOST:$PORT</h1>
    <div class="summary">
        <p><strong>Target URL:</strong> $URL</p>
        <p><strong>Scan Date:</strong> $(date)</p>
        <p><strong>Output Directory:</strong> $OUTPUT_DIR</p>
    </div>
EOF

# Add results from each file to HTML report
for file in "$OUTPUT_DIR"/*.txt; do
    if [[ -f "$file" ]]; then
        BASENAME=$(basename "$file" .txt)
        echo "<h2>${BASENAME}</h2>" >> "$REPORT_FILE"
        echo "<table><tr><th>Status</th><th>Size</th><th>URL</th></tr>" >> "$REPORT_FILE"
        
        grep -E ",(200|201|204|301|302|307|401|403|500),[0-9]+,.*" "$file" 2>/dev/null | while IFS= read -r line; do
            STATUS=$(echo "$line" | cut -d',' -f2)
            SIZE=$(echo "$line" | cut -d',' -f3)
            URL_PATH=$(echo "$line" | cut -d',' -f5)
            STATUS_CLASS=""
            case $STATUS in
                200|201|204) STATUS_CLASS="status-200" ;;
                401|403) STATUS_CLASS="status-403" ;;
                500) STATUS_CLASS="status-500" ;;
            esac
            echo "<tr><td class=\"$STATUS_CLASS\">$STATUS</td><td>$SIZE</td><td>$URL_PATH</td></tr>" >> "$REPORT_FILE"
        done
        
        echo "</table>" >> "$REPORT_FILE"
    fi
done

cat >> "$REPORT_FILE" << EOF
</body>
</html>
EOF

echo "\nHTML report generated: $REPORT_FILE"
echo "=================================================="
