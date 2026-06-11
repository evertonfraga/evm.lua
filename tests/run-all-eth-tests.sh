#!/bin/bash

# Run all Ethereum Foundation tests and generate a report

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="/tmp/GeneralStateTests"
REPORT_FILE="$SCRIPT_DIR/eth-test-results.txt"

echo "Running all Ethereum Foundation tests..."
echo "This may take several minutes..."
echo ""

# Clear previous report
> "$REPORT_FILE"

# Get all test categories
categories=$(ls "$TEST_DIR" | grep "^st" | sort)

total_categories=0
total_passed=0
total_failed=0
passed_categories=0
failed_categories=0

echo "Category,Passed,Failed,Total,Pass%" | tee -a "$REPORT_FILE"
echo "================================================" | tee -a "$REPORT_FILE"

for category in $categories; do
    ((total_categories++))
    
    # Run tests and capture output
    output=$(python3 "$SCRIPT_DIR/eth-test-adapter.py" "$TEST_DIR/$category" 2>&1)
    
    # Extract results
    passed=$(echo "$output" | grep "Total:" | sed 's/.*Total: \([0-9]*\) passed.*/\1/')
    failed=$(echo "$output" | grep "Total:" | sed 's/.*failed.*//' | sed 's/.*Total: [0-9]* passed, \([0-9]*\) failed.*/\1/')
    
    if [ -z "$passed" ]; then
        passed=0
    fi
    if [ -z "$failed" ]; then
        failed=0
    fi
    
    total=$((passed + failed))
    
    if [ $total -gt 0 ]; then
        pass_rate=$((passed * 100 / total))
    else
        pass_rate=0
    fi
    
    # Update totals
    total_passed=$((total_passed + passed))
    total_failed=$((total_failed + failed))
    
    if [ $failed -eq 0 ] && [ $passed -gt 0 ]; then
        ((passed_categories++))
        status="✓"
    elif [ $failed -gt 0 ]; then
        ((failed_categories++))
        status="✗"
    else
        status="?"
    fi
    
    # Print result
    printf "%s %-40s %5d %5d %5d %4d%%\n" "$status" "$category" "$passed" "$failed" "$total" "$pass_rate" | tee -a "$REPORT_FILE"
done

echo "================================================" | tee -a "$REPORT_FILE"

# Calculate overall stats
total_tests=$((total_passed + total_failed))
if [ $total_tests -gt 0 ]; then
    overall_pass_rate=$((total_passed * 100 / total_tests))
else
    overall_pass_rate=0
fi

echo "" | tee -a "$REPORT_FILE"
echo "SUMMARY" | tee -a "$REPORT_FILE"
echo "================================================" | tee -a "$REPORT_FILE"
echo "Categories tested:     $total_categories" | tee -a "$REPORT_FILE"
echo "Categories passed:     $passed_categories (100% pass rate)" | tee -a "$REPORT_FILE"
echo "Categories with fails: $failed_categories" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"
echo "Total tests:           $total_tests" | tee -a "$REPORT_FILE"
echo "Tests passed:          $total_passed" | tee -a "$REPORT_FILE"
echo "Tests failed:          $total_failed" | tee -a "$REPORT_FILE"
echo "Overall pass rate:     $overall_pass_rate%" | tee -a "$REPORT_FILE"
echo "================================================" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"
echo "Detailed results saved to: $REPORT_FILE"
