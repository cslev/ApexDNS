#!/bin/bash

# Script to extract domains with HTTPS + H3 support and query for ipv4hint IPs
# Usage: ./extract_ipv4hints.sh <input_file>

INPUT_FILE="${1:-crux_https_h3_results_21JAN2026_1103.txt}"
# Generate timestamp in DDMMMYYYY_HHMM format
TIMESTAMP=$(date +"%d%b%Y_%H%M" | tr '[:lower:]' '[:upper:]')
OUTPUT_FILE="ipv4hints_${TIMESTAMP}.txt"
LOG_FILE="ipv4hints_extract_${TIMESTAMP}.log"
DELAY=1  # delay in seconds between queries

# Initialize counters
total_domains=0
domains_with_ipv4hint=0
total_ips=0

echo "Starting ipv4hint extraction at $(date)" > "$LOG_FILE"
echo "Input file: $INPUT_FILE" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Clear output file
> "$OUTPUT_FILE"

# Extract domains with "HTTPS + H3" from input file
domains=$(grep "HTTPS + H3" "$INPUT_FILE" | cut -d':' -f1 | tr -d ' ')

echo "Found $(echo "$domains" | wc -l) domains with HTTPS + H3 support" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Process each domain
for domain in $domains; do
    ((total_domains++))
    
    echo "[$total_domains] Querying $domain for HTTPS record..." | tee -a "$LOG_FILE"
    
    # Perform dig query for HTTPS record
    dig_output=$(dig +short "$domain" TYPE65 2>&1)
    
    if [ -n "$dig_output" ]; then
        # Extract ipv4hint field using grep and sed
        # HTTPS records format: priority target params
        # ipv4hint is typically in the params section
        ipv4hints=$(echo "$dig_output" | grep -oP 'ipv4hint=[\d.,]+' | sed 's/ipv4hint=//' | tr ',' '\n')
        
        if [ -n "$ipv4hints" ]; then
            ((domains_with_ipv4hint++))
            echo "  ✓ Found ipv4hint(s)" | tee -a "$LOG_FILE"
            
            # Count and save IPs
            while IFS= read -r ip; do
                if [ -n "$ip" ]; then
                    echo "$ip" >> "$OUTPUT_FILE"
                    ((total_ips++))
                    echo "    - $ip" | tee -a "$LOG_FILE"
                fi
            done <<< "$ipv4hints"
        else
            echo "  - No ipv4hint found" | tee -a "$LOG_FILE"
        fi
    else
        echo "  - No HTTPS record" | tee -a "$LOG_FILE"
    fi
    
    # Progress update every 50 domains
    if [ $((total_domains % 50)) -eq 0 ]; then
        echo "" | tee -a "$LOG_FILE"
        echo "Progress: $total_domains domains processed" | tee -a "$LOG_FILE"
        echo "  - Domains with ipv4hint: $domains_with_ipv4hint" | tee -a "$LOG_FILE"
        echo "  - Total IPs collected: $total_ips" | tee -a "$LOG_FILE"
        echo "" | tee -a "$LOG_FILE"
    fi
    
    # Sleep to avoid overwhelming DNS
    sleep "$DELAY"
done

# Final statistics
echo "" | tee -a "$LOG_FILE"
echo "======================================" | tee -a "$LOG_FILE"
echo "Extraction completed at: $(date)" | tee -a "$LOG_FILE"
echo "======================================" | tee -a "$LOG_FILE"
echo "Total domains processed: $total_domains" | tee -a "$LOG_FILE"
echo "Domains with ipv4hint: $domains_with_ipv4hint" | tee -a "$LOG_FILE"
echo "Total IPs collected: $total_ips" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Calculate percentage
if [ $total_domains -gt 0 ]; then
    ipv4hint_percentage=$(awk "BEGIN {printf \"%.2f\", ($domains_with_ipv4hint / $total_domains) * 100}")
    echo "ipv4hint presence rate: $ipv4hint_percentage%" | tee -a "$LOG_FILE"
fi

echo ""
echo "IPs saved to $OUTPUT_FILE"
echo "Log saved to $LOG_FILE"
echo "Total IPs extracted: $total_ips"
