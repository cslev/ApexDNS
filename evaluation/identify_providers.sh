#!/bin/bash

# Script to identify service providers from IP addresses via reverse DNS and SOA records
# Usage: ./identify_providers.sh <input_file>

INPUT_FILE="${1:-ipv4hints_26JAN2026_1144.txt}"
# Generate timestamp in DDMMMYYYY_HHMM format
TIMESTAMP=$(date +"%d%b%Y_%H%M" | tr '[:lower:]' '[:upper:]')
OUTPUT_FILE="providers_${TIMESTAMP}.txt"
PROVIDERS_SUMMARY="providers_summary_${TIMESTAMP}.txt"
LOG_FILE="providers_extract_${TIMESTAMP}.log"
DELAY=1  # delay in seconds between queries

# Initialize counters
total_ips=0
ips_with_ptr=0
ips_with_soa=0

echo "Starting provider identification at $(date)" > "$LOG_FILE"
echo "Input file: $INPUT_FILE" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Clear output files
> "$OUTPUT_FILE"
> "$PROVIDERS_SUMMARY"

# Read IP addresses from input file
while IFS= read -r ip; do
    # Skip empty lines
    [ -z "$ip" ] && continue
    
    ((total_ips++))
    
    echo "[$total_ips] Checking $ip..." | tee -a "$LOG_FILE"
    
    # Perform reverse DNS lookup and get full output
    dig_output=$(dig -x "$ip" 2>&1)
    
    # Extract PTR record
    ptr_record=$(echo "$dig_output" | grep -A1 "ANSWER SECTION" | grep "PTR" | awk '{print $NF}' | head -1 | sed 's/\.$//')
    
    if [ -n "$ptr_record" ]; then
        ((ips_with_ptr++))
        echo "  ✓ PTR: $ptr_record" | tee -a "$LOG_FILE"
        
        # Extract domain from PTR record (get last two parts typically)
        # e.g., server.cloudflare.com -> cloudflare.com
        # or ec2-1-2-3-4.compute.amazonaws.com -> amazonaws.com
        provider_domain=$(echo "$ptr_record" | awk -F'.' '{if (NF>=2) print $(NF-1)"."$NF; else print $0}')
        
        # Extract SOA record from the same dig output
        soa_ns=$(echo "$dig_output" | grep "SOA" | awk '{print $5}' | head -1 | sed 's/\.$//')
        
        if [ -n "$soa_ns" ]; then
            ((ips_with_soa++))
            echo "  ✓ SOA NS: $soa_ns" | tee -a "$LOG_FILE"
            
            # Save to output file
            echo "$ip|$ptr_record|$provider_domain|$soa_ns" >> "$OUTPUT_FILE"
        else
            echo "  - No SOA record for $provider_domain" | tee -a "$LOG_FILE"
            echo "$ip|$ptr_record|$provider_domain|NO_SOA" >> "$OUTPUT_FILE"
        fi
        
        # Add provider to summary (for counting)
        echo "$provider_domain" >> "$PROVIDERS_SUMMARY"
    else
        echo "  - No PTR record" | tee -a "$LOG_FILE"
        echo "$ip|NO_PTR|UNKNOWN|NO_SOA" >> "$OUTPUT_FILE"
    fi
    
    # Progress update every 100 IPs
    if [ $((total_ips % 100)) -eq 0 ]; then
        echo "" | tee -a "$LOG_FILE"
        echo "Progress: $total_ips IPs processed" | tee -a "$LOG_FILE"
        echo "  - IPs with PTR: $ips_with_ptr" | tee -a "$LOG_FILE"
        echo "  - IPs with SOA: $ips_with_soa" | tee -a "$LOG_FILE"
        echo "" | tee -a "$LOG_FILE"
    fi
    
    # Sleep to avoid overwhelming DNS
    sleep "$DELAY"
    
done < "$INPUT_FILE"

# Generate provider statistics
echo "Generating provider statistics..." | tee -a "$LOG_FILE"
provider_stats=$(sort "$PROVIDERS_SUMMARY" | uniq -c | sort -rn)

# Save statistics to summary file
echo "Provider Statistics" > "$PROVIDERS_SUMMARY"
echo "===================" >> "$PROVIDERS_SUMMARY"
echo "Generated at: $(date)" >> "$PROVIDERS_SUMMARY"
echo "" >> "$PROVIDERS_SUMMARY"
echo "$provider_stats" >> "$PROVIDERS_SUMMARY"

# Final statistics
echo "" | tee -a "$LOG_FILE"
echo "======================================" | tee -a "$LOG_FILE"
echo "Provider identification completed at: $(date)" | tee -a "$LOG_FILE"
echo "======================================" | tee -a "$LOG_FILE"
echo "Total IPs processed: $total_ips" | tee -a "$LOG_FILE"
echo "IPs with PTR records: $ips_with_ptr" | tee -a "$LOG_FILE"
echo "IPs with SOA records: $ips_with_soa" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Calculate percentages
if [ $total_ips -gt 0 ]; then
    ptr_percentage=$(awk "BEGIN {printf \"%.2f\", ($ips_with_ptr / $total_ips) * 100}")
    echo "PTR record rate: $ptr_percentage%" | tee -a "$LOG_FILE"
    
    soa_percentage=$(awk "BEGIN {printf \"%.2f\", ($ips_with_soa / $total_ips) * 100}")
    echo "SOA record rate: $soa_percentage%" | tee -a "$LOG_FILE"
fi

echo ""
echo "Results saved to $OUTPUT_FILE (format: IP|PTR|PROVIDER|SOA_NS)"
echo "Provider statistics saved to $PROVIDERS_SUMMARY"
echo "Log saved to $LOG_FILE"
echo ""
echo "Top 10 providers:"
head -10 <<< "$provider_stats"
