#!/bin/bash

region_endpoint=eu-central-1
region=eu-north-1
# aws pricing describe-services --region "${region_endpoint}" --service-code AWSLambda > lambda_describe.json
# aws pricing get-attribute-values --service-code AWSLambda --attribute-name usageType --region "${region_endpoint}" > lambda_values.json
# eu-north-1




function get_lambda_price() {
    # based on benchmark
    memory=128.0
    # in seconds
    duration=$1
    #GB-S
    gb_s_duration=$(echo "memory * duration" | bc)
    # check tiers
    tier=3
    if [[ $gb_s_duration -gt 6000000000000 && $gb_s_duration -lt 9000000000000 ]]; then
        tier=2
    elif  [[ $gb_s_duration -gt 9000000000000 ]]; then
        tier=1
    fi
    price_per_gb_second=$(aws pricing get-products --region "${region_endpoint}" --service-code AWSLambda --filters Type=TERM_MATCH,Field=regionCode,Value="${region}" \
    Type=TERM_MATCH,Field=usageType,Value=EUN1-Lambda-GB-Second  --query 'PriceList[0]' | tr -d '\\' | sed 's/^.//;s/.$//' \
    | jq '.terms.OnDemand' | jq -r 'to_entries[0].value.priceDimensions | to_entries[:3] | .[] | .value.pricePerUnit.USD' | tr "\n" " " \
    | cut -d" " -f${tier})

    # Cost (Memory in GB * Duration in seconds) * Price per GB-Second
    echo $(echo "scale=10; ($memory * $duration) * $price_per_gb_second" | bc)
}

function get_requests_duration() {
    views=$1
    add_views=$(echo "$views * 0.05" | bc)
    update_views=$(echo "$views * 0.05" | bc)
    delete_views=$(echo "$views * 0.05" | bc)
    search_views=$(echo "$views * 0.15" | bc)
    get_views=$(echo "$views * 0.7" | bc)
    # based on avg duration
    echo "$add_views * 0.1252236 + $get_views * 0.0071847 + $update_views * 0.0135427 + $search_views * 0.3957469 + $delete_views * 0.0096585" | bc
}

# per month
number_of_visitors=$1
total_requests_duration=$(get_requests_duration $number_of_visitors)
echo $total_requests_duration
get_lambda_price $total_requests_duration