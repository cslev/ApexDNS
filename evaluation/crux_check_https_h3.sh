#!/bin/bash

# Script to check HTTPS DNS records and H3 support for Google CrUX top-5000 domains using `dig domain HTTPS +short`
# Usage: ./crux_check_https_h3.sh

CSV_FILE="google_crux_5000.csv"
# Generate timestamp in DDMMMYYYY_HHMM format
TIMESTAMP=$(date +"%d%b%Y_%H%M" | tr '[:lower:]' '[:upper:]')
OUTPUT_FILE="crux_https_h3_results_${TIMESTAMP}.txt"
LOG_FILE="crux_https_h3_scan_${TIMESTAMP}.log"
DELAY=2  # delay in seconds between queries

# Initialize counters
total_domains=0
domains_with_https=0
domains_with_h3=0

# Clear/create output files
echo "HTTPS and H3 Support Analysis (Google CrUX)" > "$OUTPUT_FILE"
echo "Started at: $(date)" >> "$OUTPUT_FILE"
echo "======================================" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

echo "Starting scan at $(date)" > "$LOG_FILE"

# Read CSV file line by line
while IFS=',' read -r url score; do
    # Increment total counter
    ((total_domains++))
    
    # Skip empty lines
    [ -z "$url" ] && continue
    
    # Extract domain from URL: remove https:// or http:// only
    domain=$(echo "$url" | sed -e 's|^https\?://||' | tr -d '\r\n' | xargs)
    
    # Skip if domain is empty after processing
    [ -z "$domain" ] && continue
    
    echo "[$total_domains] Querying $domain..." | tee -a "$LOG_FILE"
    
    # Perform dig query for HTTPS record type (type65)
    dig_output=$(dig +short "$domain" TYPE65 2>&1)
    
    # Check if we got any HTTPS records
    if [ -n "$dig_output" ]; then
        ((domains_with_https++))
        echo "  ✓ Has HTTPS record" | tee -a "$LOG_FILE"
        
        # Check if the response contains 'h3'
        if echo "$dig_output" | grep -iq "h3"; then
            ((domains_with_h3++))
            echo "  ✓✓ Supports H3" | tee -a "$LOG_FILE"
            echo "$domain: HTTPS + H3" >> "$OUTPUT_FILE"
        else
            echo "  - No H3 support" | tee -a "$LOG_FILE"
            echo "$domain: HTTPS only" >> "$OUTPUT_FILE"
        fi
    else
        echo "  - No HTTPS record" | tee -a "$LOG_FILE"
    fi
    
    # Progress update every 100 domains
    if [ $((total_domains % 100)) -eq 0 ]; then
        echo "" | tee -a "$LOG_FILE"
        echo "Progress: $total_domains domains processed" | tee -a "$LOG_FILE"
        echo "  - HTTPS records: $domains_with_https" | tee -a "$LOG_FILE"
        echo "  - H3 support: $domains_with_h3" | tee -a "$LOG_FILE"
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
echo "Domains with HTTPS records: $domains_with_https" | tee -a "$LOG_FILE"
echo "Domains with H3 support: $domains_with_h3" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Calculate percentages
if [ $total_domains -gt 0 ]; then
    https_percentage=$(awk "BEGIN {printf \"%.2f\", ($domains_with_https / $total_domains) * 100}")
    echo "HTTPS adoption rate: $https_percentage%" | tee -a "$LOG_FILE"
fi

if [ $domains_with_https -gt 0 ]; then
    h3_percentage=$(awk "BEGIN {printf \"%.2f\", ($domains_with_h3 / $domains_with_https) * 100}")
    echo "H3 adoption rate (among HTTPS): $h3_percentage%" | tee -a "$LOG_FILE"
fi

# Append summary to output file
echo "" >> "$OUTPUT_FILE"
echo "======================================" >> "$OUTPUT_FILE"
echo "SUMMARY" >> "$OUTPUT_FILE"
echo "======================================" >> "$OUTPUT_FILE"
echo "Total domains: $total_domains" >> "$OUTPUT_FILE"
echo "HTTPS records: $domains_with_https" >> "$OUTPUT_FILE"
echo "H3 support: $domains_with_h3" >> "$OUTPUT_FILE"
if [ $total_domains -gt 0 ]; then
    echo "HTTPS adoption: $https_percentage%" >> "$OUTPUT_FILE"
fi
if [ $domains_with_https -gt 0 ]; then
    echo "H3 adoption (among HTTPS): $h3_percentage%" >> "$OUTPUT_FILE"
fi

echo ""
echo "Results saved to $OUTPUT_FILE"
echo "Log saved to $LOG_FILE"
