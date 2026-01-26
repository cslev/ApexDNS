#!/bin/bash

# Script to check alt-svc headers for H3/QUIC support for the top-5000 domains using `curl -I https://domain`
# Usage: ./check_altsvc_h3.sh

CSV_FILE="tranco_5000.csv"
# Generate timestamp in DDMMMYYYY_HHMM format
TIMESTAMP=$(date +"%d%b%Y_%H%M" | tr '[:lower:]' '[:upper:]')
OUTPUT_FILE="altsvc_h3_results_${TIMESTAMP}.txt"
LOG_FILE="altsvc_h3_scan_${TIMESTAMP}.log"
DELAY=2  # delay in seconds between queries
TIMEOUT=10  # curl timeout in seconds

# Initialize counters
total_domains=0
domains_with_altsvc=0
domains_with_h3=0
domains_reachable=0
domains_unreachable=0

# Clear/create output files
echo "Alt-Svc and H3 Support Analysis" > "$OUTPUT_FILE"
echo "Started at: $(date)" >> "$OUTPUT_FILE"
echo "======================================" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "Starting scan at $(date)" > "$LOG_FILE"

# Read CSV file line by line
while IFS=',' read -r rank domain; do
    # Increment total counter
    ((total_domains++))
    
    # Skip empty lines
    [ -z "$domain" ] && continue
    
    # Remove any whitespace or carriage returns
    domain=$(echo "$domain" | tr -d '\r\n' | xargs)
    
    echo "[$total_domains] Checking $domain..." | tee -a "$LOG_FILE"
    
    # Try HTTPS first, then HTTP if HTTPS fails
    headers=$(curl -I -s -L --max-time "$TIMEOUT" "https://$domain" 2>&1)
    
    # Check if curl succeeded
    if [ $? -eq 0 ] && echo "$headers" | grep -qi "HTTP/"; then
        ((domains_reachable++))
        echo "  ✓ Domain reachable" | tee -a "$LOG_FILE"
        
        # Extract alt-svc header (case-insensitive)
        altsvc_header=$(echo "$headers" | grep -i "^alt-svc:")
        
        if [ -n "$altsvc_header" ]; then
            ((domains_with_altsvc++))
            echo "  ✓ Has alt-svc header" | tee -a "$LOG_FILE"
            echo "    $altsvc_header" | tee -a "$LOG_FILE"
            
            # Check if alt-svc contains 'h3'
            if echo "$altsvc_header" | grep -iq "h3"; then
                ((domains_with_h3++))
                echo "  ✓✓ Supports H3 via alt-svc" | tee -a "$LOG_FILE"
                echo "$domain: alt-svc + H3" >> "$OUTPUT_FILE"
                echo "  Header: $altsvc_header" >> "$OUTPUT_FILE"
                echo "" >> "$OUTPUT_FILE"
            else
                echo "  - No H3 in alt-svc" | tee -a "$LOG_FILE"
                echo "$domain: alt-svc only (no H3)" >> "$OUTPUT_FILE"
            fi
        else
            echo "  - No alt-svc header" | tee -a "$LOG_FILE"
        fi
    else
        ((domains_unreachable++))
        echo "  ✗ Domain unreachable or timeout" | tee -a "$LOG_FILE"
    fi
    
    # Progress update every 100 domains
    if [ $((total_domains % 100)) -eq 0 ]; then
        echo "" | tee -a "$LOG_FILE"
        echo "Progress: $total_domains domains processed" | tee -a "$LOG_FILE"
        echo "  - Reachable: $domains_reachable" | tee -a "$LOG_FILE"
        echo "  - Unreachable: $domains_unreachable" | tee -a "$LOG_FILE"
        echo "  - With alt-svc: $domains_with_altsvc" | tee -a "$LOG_FILE"
        echo "  - With H3 support: $domains_with_h3" | tee -a "$LOG_FILE"
        echo "" | tee -a "$LOG_FILE"
    fi
    
    # Sleep to avoid being suspicious
    sleep "$DELAY"
    
done < "$CSV_FILE"

# Final statistics
echo "" | tee -a "$LOG_FILE"
echo "======================================" | tee -a "$LOG_FILE"
echo "Scan completed at: $(date)" | tee -a "$LOG_FILE"
echo "======================================" | tee -a "$LOG_FILE"
echo "Total domains processed: $total_domains" | tee -a "$LOG_FILE"
echo "Reachable domains: $domains_reachable" | tee -a "$LOG_FILE"
echo "Unreachable domains: $domains_unreachable" | tee -a "$LOG_FILE"
echo "Domains with alt-svc header: $domains_with_altsvc" | tee -a "$LOG_FILE"
echo "Domains with H3 support: $domains_with_h3" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Calculate percentages
if [ $total_domains -gt 0 ]; then
    reachable_percentage=$(awk "BEGIN {printf \"%.2f\", ($domains_reachable / $total_domains) * 100}")
    echo "Reachability rate: $reachable_percentage%" | tee -a "$LOG_FILE"
fi

if [ $domains_reachable -gt 0 ]; then
    altsvc_percentage=$(awk "BEGIN {printf \"%.2f\", ($domains_with_altsvc / $domains_reachable) * 100}")
    echo "Alt-svc adoption rate: $altsvc_percentage%" | tee -a "$LOG_FILE"
    
    h3_percentage=$(awk "BEGIN {printf \"%.2f\", ($domains_with_h3 / $domains_reachable) * 100}")
    echo "H3 adoption rate: $h3_percentage%" | tee -a "$LOG_FILE"
fi

if [ $domains_with_altsvc -gt 0 ]; then
    h3_in_altsvc=$(awk "BEGIN {printf \"%.2f\", ($domains_with_h3 / $domains_with_altsvc) * 100}")
    echo "H3 in alt-svc headers: $h3_in_altsvc%" | tee -a "$LOG_FILE"
fi

# Append summary to output file
echo "" >> "$OUTPUT_FILE"
echo "======================================" >> "$OUTPUT_FILE"
echo "SUMMARY" >> "$OUTPUT_FILE"
echo "======================================" >> "$OUTPUT_FILE"
echo "Total domains: $total_domains" >> "$OUTPUT_FILE"
echo "Reachable: $domains_reachable" >> "$OUTPUT_FILE"
echo "Unreachable: $domains_unreachable" >> "$OUTPUT_FILE"
echo "Alt-svc headers: $domains_with_altsvc" >> "$OUTPUT_FILE"
echo "H3 support: $domains_with_h3" >> "$OUTPUT_FILE"
if [ $total_domains -gt 0 ]; then
    echo "Reachability: $reachable_percentage%" >> "$OUTPUT_FILE"
fi
if [ $domains_reachable -gt 0 ]; then
    echo "Alt-svc adoption: $altsvc_percentage%" >> "$OUTPUT_FILE"
    echo "H3 adoption: $h3_percentage%" >> "$OUTPUT_FILE"
fi

echo ""
echo "Results saved to $OUTPUT_FILE"
echo "Log saved to $LOG_FILE"
