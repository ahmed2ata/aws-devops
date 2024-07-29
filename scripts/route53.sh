region="us-east-1"
dns_name="devops90.com"
private_dns_name="ourapp.prod"
vpc_name="devops90-vpc"

check_vpc=$(aws ec2 describe-vpcs --region us-east-1 --filters Name=tag:Name,Values=$vpc_name | grep -oP '(?<="VpcId": ")[^"]*')
if [ "$check_vpc" == "" ]; then

    vpc_result=$(aws ec2 create-vpc \
        --cidr-block 10.0.0.0/16 --region us-east-1 \
        --tag-specification ResourceType=vpc,Tags="[{Key=Name,Value=$vpc_name}]" \
        --output json)
    echo $vpc_result

    vpc_id=$(echo $vpc_result | grep -oP '(?<="VpcId": ")[^"]*')
    echo $vpc_id

    if [ "$vpc_id" == "" ]; then
        echo "Error in creating the VPC"
        exit 1
    fi

    echo "VPC created."

else
    echo "VPC already exists"
    vpc_id=$check_vpc
    echo $vpc_id
fi

created_private_hosted_zone() {
    check_zone=$(aws route53 list-hosted-zones-by-name --query "HostedZones[?Name == '$private_dns_name.']" | grep -oP '(?<="Id": ")[^"]*')
    if [ "$check_zone" == "" ]; then
       echo "Hosted Zone will be created ..."
       time=$(date -u +"%Y-%m-%d-%H-%M-%S")
       hosted_zone_id=$(aws route53 create-hosted-zone --hosted-zone-config "{\"PrivateZone\":true}" --vpc "{\"VPCRegion\":\"$region\",\"VPCId\":\"$vpc_id\"}" --name $private_dns_name --caller-reference $time --query "HostedZone.Id" --output text)
        if [ "$hosted_zone_id" == "" ]; then
            echo "Error in creating Hosted Zone"
            exit 1
        fi
        echo "Hosted Zone created."
    else
        echo "Hosted Zone already exists."
        hosted_zone_id=$check_zone
    fi
}
created_private_hosted_zone
#........................................................................

get_instance_ip()
{
    # $1 ec2 Name
    ec2_ip=$(aws ec2 describe-instances --region $region --filters Name=tag:Name,Values=$1 Name=instance-state-name,Values=running | grep -oP "(?<=\"PrivateIpAddress\": \")[^\"]*" | uniq)
    if [ "$ec2_ip" == "" ]; then
        echo "EC2 with name: '$1' not exist. we will create one"
        exit 1
    else
        echo "EC2 found. private ip: $ec2_ip"
    fi
}
get_instance_ip "devops90"
#.............................................................................
create_dns_record() 
{
       full_sub_domain=private.$private_dns_name
       change=$(cat << EOF
{
  "Changes": 
  [
    {
      "Action": "CREATE",
      "ResourceRecordSet": 
      {
        "Name": "$full_sub_domain",
        "Type": "A",
        "TTL": 300,
        "ResourceRecords": 
        [
          {
            "Value": "$2"
          }
        ]
      }
    }
  ]
}
EOF
)
    change=$( echo $change | tr -d '\n' | tr -d ' ')
    check_record=$(aws route53 list-resource-record-sets --hosted-zone-id $hosted_zone_id --query "ResourceRecordSets[?Name == '$full_sub_domain.']" | grep -oP '(?<="Name": ")[^"]*')
    if [ "$check_record" == "" ]; then
        echo "DNS Record will be created ..."
        change_info=$(aws route53 change-resource-record-sets --hosted-zone-id $hosted_zone_id --change-batch $change)
        echo $change_info
    else
        echo "DNS Record already exist."
    fi
}
create_dns_record srv $ec2_ip "Private"
