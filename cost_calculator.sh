#!/bin/bash

region_endpoint=eu-central-1
region=eu-north-1
# https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/price-list-query-api-find-services.html

function get_lambda_price() {
    # based on benchmark, in GB
    memory=0.125
    # in seconds
    duration=$1
    total_requests=$2
    #GB-S
    gb_s_duration=$(scale=10;echo "$memory * $duration" | bc)
    gb_s_duration=$(printf '%.0f\n' "$gb_s_duration")

    price_per_gb_second=$(aws pricing get-products --region "${region_endpoint}" --service-code AWSLambda --filters Type=TERM_MATCH,Field=regionCode,Value="${region}" \
    Type=TERM_MATCH,Field=usageType,Value=EUN1-Lambda-GB-Second  --query 'PriceList[0]' | tr -d '\\' | sed 's/^.//;s/.$//' \
    | jq '.terms.OnDemand' | jq -r 'to_entries[0].value.priceDimensions | to_entries[:3] | .[] | .value.pricePerUnit.USD' | tr "\n" " ")
    price_per_request=$(aws pricing get-products --region "${region_endpoint}" --service-code AWSLambda --filters Type=TERM_MATCH,Field=regionCode,Value="${region}" \
    Type=TERM_MATCH,Field=usageType,Value=EUN1-Request  --query 'PriceList[0]' | tr -d '\\' | sed 's/^.//;s/.$//' \
    | jq '.terms.OnDemand' | jq -r 'to_entries[0].value.priceDimensions | to_entries[0].value.pricePerUnit.USD')
    
    price_1=$(echo $price_per_gb_second | cut -d" " -f3)
    price_2=$(echo $price_per_gb_second | cut -d" " -f2)
    price_3=$(echo $price_per_gb_second | cut -d" " -f1)
    cost_request=$(echo "$price_per_request * $total_requests" | bc)
    gb_s_duration=$(printf '%.0f\n' "$gb_s_duration")

    if [[ $gb_s_duration -le 6000000000000 ]]; then
        echo "$price_1 * $gb_s_duration + $cost_request" | bc
    elif  [[ $gb_s_duration -le 9000000000000 ]]; then
        rest=$(echo "$gb_s_duration - 6000000000000" | bc)
        echo "$price_1 * 6000000000000 + $rest * $price_2 + $cost_request" | bc        
    else
        rest=$(echo "$gb_s_duration - 9000000000000" | bc)
        echo "$price_1 * 6000000000000 + $price_2 * (9000000000000 - 6000000000000) + $rest * $price_3 + $cost_request" | bc
    fi
}

function get_requests_duration() {
    views=$1
    add_views=$(echo "$views * 0.05" | bc)
    update_views=$(echo "$views * 0.05" | bc)
    delete_views=$(echo "$views * 0.05" | bc)
    search_views=$(echo "$views * 0.15" | bc)
    get_views=$(echo "$views * 1" | bc)
    # based on avg duration
    duration=$(echo "$add_views * 0.1252236 + $get_views * 0.0071847 + $update_views * 0.0135427 + $search_views * 0.3957469 + $delete_views * 0.0096585" | bc)
    printf '%.0f\n' "$duration"
}

function calculate_s3() {
    static_files_size=$1
    number_of_visits=$2
    # Date-transfer out
    transfer_out=$(aws pricing get-products --region "${region_endpoint}" --service-code AWSDataTransfer --filters Type=TERM_MATCH,Field=fromRegionCode,Value="${region}" \
    Type=TERM_MATCH,Field=toLocation,Value="External"  Type=TERM_MATCH,Field=usagetype,Value="EUN1-DataTransfer-Out-Bytes" --query 'PriceList[0]' \
    | tr -d '\\' | sed 's/^.//;s/.$//' | jq '.terms.OnDemand' | jq -r 'to_entries[0].value.priceDimensions | to_entries[0].value.pricePerUnit.USD')

    # Storage
    storage_size=$(aws pricing get-products --region "${region_endpoint}" --service-code AmazonS3 --filters Type=TERM_MATCH,Field=regionCode,Value="${region}" \
    Type=TERM_MATCH,Field=usageType,Value=EUN1-TimedStorage-ByteHrs Type=TERM_MATCH,Field=storageClass,Value="General Purpose" \
    --query 'PriceList[0]' | tr -d '\\' | sed 's/^.//;s/.$//' | jq -r '.terms.OnDemand | to_entries[0].value.priceDimensions | to_entries[0].value.pricePerUnit.USD')

    # GET requests per 1000
    req_get=$(aws pricing get-products --region "${region_endpoint}" --service-code AmazonS3 --filters Type=TERM_MATCH,Field=regionCode,Value="${region}" \
    Type=TERM_MATCH,Field=usageType,Value=EUN1-AdditionalRequest-INT --query 'PriceList[0]' | tr -d '\\' | sed 's/^.//;s/.$//' \
    | jq -r '.terms.OnDemand | to_entries[0].value.priceDimensions | to_entries[0].value.pricePerUnit.USD')
    echo "scale=4; ($storage_size * $static_files_size / 1000) + ($transfer_out * $number_of_visits * 1.3 * 27 / 1000000000) + ($req_get * $number_of_visits / 1000)" | bc
}

function calucate_api_gateway() {
    # First 333 million	$3.50
    # Next 667 million	$3.03
    # Next 19 billion	$2.58
    # Over 20 billion	$1.64
    
    requests_no=$(echo "$1 * 1.3" | bc)
    prices=$(aws pricing get-products --region "${region_endpoint}" --service-code AmazonApiGateway --filters Type=TERM_MATCH,Field=regionCode,Value="${region}" \
    Type=TERM_MATCH,Field=usagetype,Value=EUN1-ApiGatewayRequest --query 'PriceList[0]' | tr -d '\\' | sed 's/^.//;s/.$//' \
    | jq -r '.terms.OnDemand | to_entries[0].value.priceDimensions | to_entries[:5] | .[] | .value.pricePerUnit.USD' | tr "\n" " ")
     
    price_1=$(echo $prices | cut -d" " -f2)
    price_2=$(echo $prices | cut -d" " -f4)
    price_3=$(echo $prices | cut -d" " -f3)
    price_4=$(echo $prices | cut -d" " -f1)

    requests_no=$(printf '%.0f\n' "$requests_no")

    if [[ $requests_no -le 333000000 ]]; then
        echo "$price_1 * $requests_no" | bc
    elif  [[ $requests_no -le 1000000000 ]]; then
        rest=$(echo "$requests_no - 333000000" | bc)
        echo "$price_1 * 333000000 + $rest * $price_2" | bc        
    elif [[ $requests_no -le 20000000000 ]]; then
        rest=$(echo "$requests_no - 1000000000" | bc)
        echo "$price_1 * 333000000 + $price_2 * (1000000000 - 333000000) + $rest * $price_3" | bc
    else
        rest=$(echo "$requests_no - 20000000000" | bc)
        echo "$price_1 * 333000000 + $price_2 * (1000000000 - 333000000) + $price_3 * (20000000000 - 1000000000 - 333000000) + $rest * $price_4" | bc
    fi
}

function calculate_lb() {
    lb_usage=$(aws pricing get-products --region "${region_endpoint}" --service-code AWSELB --filters Type=TERM_MATCH,Field=regionCode,Value="${region}" \
    Type=TERM_MATCH,Field=productFamily,Value="Load Balancer" Type=TERM_MATCH,Field=usagetype,Value="EUN1-LoadBalancerUsage" --query 'PriceList[0]')
    lb_processing=$(aws pricing get-products --region "${region_endpoint}" --service-code AWSELB --filters Type=TERM_MATCH,Field=regionCode,Value="${region}" \
    Type=TERM_MATCH,Field=productFamily,Value="Load Balancer" Type=TERM_MATCH,Field=usagetype,Value="EUN1-DataProcessing-Bytes" --query 'PriceList[0]')
    lb_usage_price=$(echo $lb_usage | tr -d '\\' | sed 's/^.//;s/.$//' \
    | jq -r '.terms.OnDemand | to_entries[0].value.priceDimensions | to_entries[:5] | .[] | .value.pricePerUnit.USD')
    lb_processing_price=$(echo $lb_processing | tr -d '\\' | sed 's/^.//;s/.$//' \
    | jq -r '.terms.OnDemand | to_entries[0].value.priceDimensions | to_entries[:5] | .[] | .value.pricePerUnit.USD')
    echo "$1 * $lb_processing_price + 24 * 30 * $lb_usage_price" | bc
}

function calculate_ec2() {
    # dla on-demand!
    instance_type=$1
    storage_needed=$(echo "scale=2;$2 / 1000 + 3" | bc)
    price_per_month=$(aws pricing get-products --region "${region_endpoint}" --service-code AmazonEC2 --filters Type=TERM_MATCH,Field=regionCode,Value="${region}" \
    Type=TERM_MATCH,Field=instanceType,Value=${instance_type} Type=TERM_MATCH,Field=operatingSystem,Value=Linux \
    Type=TERM_MATCH,Field=usagetype,Value=EUN1-BoxUsage:${instance_type} Type=TERM_MATCH,Field=operation,Value=RunInstances --query 'PriceList[0]' | \
    tr -d '\\' | sed 's/^.//;s/.$//' | jq -r '.terms.OnDemand | to_entries[0].value.priceDimensions | to_entries[0].value.pricePerUnit.USD')
    ebs_storage=$(aws pricing get-products --region "${region_endpoint}" --service-code AmazonEC2 --filters Type=TERM_MATCH,Field=regionCode,Value="${region}" \
     Type=TERM_MATCH,Field=productFamily,Value="Storage" Type=TERM_MATCH,Field=usagetype,Value="EUN1-EBS:VolumeUsage.gp3" --query 'PriceList[0]' | \
     tr -d '\\' | sed 's/^.//;s/.$//' | jq -r '.terms.OnDemand | to_entries[0].value.priceDimensions | to_entries[0].value.pricePerUnit.USD')
    echo "$price_per_month * 24 * 30 + $ebs_storage * $storage_needed" | bc
}

# visitors number
number_of_visits=$1
#size of static files (app could be enough) in MB
static_files_size=$2
# estimated maxiamal number of users at once
maximal_number_of_users_per_second=$3
# In MB -> can be based on container size, based on estimate, It would be safe to add 3-4GB extra stroage
app_size=$4 
# size of student's page GET
average_size_of_get=54389

# In seconds, average time of page request
mid_value=0.0043
# ???? -> 5.4mb, but for avg 100mb in other case the size of instanace would be muuuuch bigger
average_ram_per_user=5.4

# ----------SERVERFUL-----------------------------------------------------
cpu=$(echo "$mid_value * $maximal_number_of_users_per_second" | bc)
cpu=$(echo "($cpu + 0.5)/1" | bc)
if [[ $cpu -eq 0 ]]; then cpu=1; fi

peak_ram=$(echo "scale=2;$maximal_number_of_users_per_second * $average_ram_per_user / 1000.0" | bc)
instance_type=$(ec2-instance-selector --memory-min $(printf '%.2f' $peak_ram) --vcpus-min $cpu --sort-by memory --sort-direction asc \
--cpu-architecture x86_64 -r eu-north-1  --max-results 1000 | grep t[0-9] | head -1)

ec2_price=$(calculate_ec2 $instance_type $app_size)
lb_price=$(calculate_lb $(echo "$average_size_of_get * $number_of_visits / 1000000000" | bc))

serverful_cost=$(echo "$ec2_price + $lb_price" | bc | tr -d "\n")

# -----------SERVERLESS---------------------------------------------------
total_requests_duration=$(get_requests_duration $number_of_visits)
lambda_price=$(get_lambda_price $total_requests_duration $(echo "$number_of_visits * 1.3" | bc))
s3_price=$(calculate_s3 $static_files_size $number_of_visits)
gateway_price=$(calucate_api_gateway $number_of_visits)
serverless_cost=$(scale=2;echo "$lambda_price + $s3_price + $gateway_price" | bc)
# ./cost_calculator.sh 43200000 50 100 600
# https://servebolt.com/articles/calculate-how-many-simultaneous-website-visitors/
# Number of CPU cores / Average time for a page request (in seconds) = Max number of Page Requests per second
# Storage -> average size* liczba użytkowników
# Maksymalna ilość uzytowników strony w jednej sekundzie!
echo "Serverful: ${serverful_cost}USD vs Serverless: ${serverless_cost}USD"