#!/bin/bash

#the followed algorithm in this script
#1 describe the resource may be it is existed
#2 if it is not created then create it
#   if there is an error exit from the script



# create vpc 10.0.0.0/16
check_vpc=$(aws ec2 describe-vpcs --region us-east-1 --filters Name=tag:Name,Values=ata-devops90-vpc | grep -oP '(?<="VpcId": ")[^"]*')
if [ "$check_vpc" == "" ]; then

    vpc_result=$(aws ec2 create-vpc \
        --cidr-block 10.0.0.0/16 --region us-east-1 \
        --tag-specification ResourceType=vpc,Tags="[{Key=Name,Value=ata-devops90-vpc}]" \
        --output json)
    echo $vpc_result

    vpc_id=$(echo $vpc_result | grep -oP '(?<="VpcId": ")[^"]*')
    echo $vpc_id

    if [ "$vpc_id" == "" ]; then
        echo "Error in creating the vpc"
        exit 1
    fi

    echo "VPC created."

else
    echo "VPC already exist"
    vpc_id=$check_vpc
    echo $vpc_id
fi
# ----------------------------------------------------------------------------
# create 4 subnets
create_subnets()
{
    # $1 for subnet number , $2 for a.z , $3 for public or private
    check_subnet=$(aws ec2 describe-subnets --region us-east-1\
        --filters Name=tag:Name,Values=atasub-$3-$1-devops90 | grep -oP '(?<="SubnetId": ")[^"]*' )
    if [ "$check_subnet" = "" ]; then
        subnet_result=$(aws ec2 create-subnet \
        --vpc-id $vpc_id --availability-zone us-east-1$2\
        --cidr-block 10.0.$1.0/24 \
        --tag-specifications ResourceType=subnet,Tags="[{Key=Name,Value=atasub-$3-$1-devops90}]" --output json)
        echo $subnet_result
        subnet_id=$(echo $subnet_result | grep -oP '(?<="SubnetId": ")[^"]*')
        echo $subnet_id

        if [ "$subnet_id" = "" ]; then
        echo "there is an error for creating subnet $1"
        exist 1
        else
        echo "subnet $1 created"  

        fi
    else
        echo "subnet $1 already exist"
        subnet_id=$check_subnet
        echo $subnet_id    
    fi
}

create_subnets 1 a public
sub1_id=$subnet_id

create_subnets 2 b public
sub2_id=$subnet_id

create_subnets 3 a private
sub3_id=$subnet_id

create_subnets 4 b private
sub4_id=$subnet_id
#---------------------------------------------------------------------------------
#create internet getway
check_igw=$(aws ec2 describe-internet-gateways  --filters Name=tag:Name,Values=atadevops90-igw | grep -oP '(?<="InternetGatewayId": ")[^"]*')
if [ "$check_igw" == "" ]; then
    echo "internet gateway will be created"

    igw_id=$(aws ec2 create-internet-gateway --region us-east-1 \
        --tag-specifications ResourceType=internet-gateway,Tags="[{Key=Name,Value=atadevops90-igw}]" --output json | grep -oP '(?<="InternetGatewayId": ")[^"]*')

    if [ "$igw_id" == "" ]; then
        echo "Error in create internet gateway"
        exit 1
    fi
    echo "internet gateway created."
    
else
    echo "internet gateway already exist"
    igw_id=$check_igw
fi

echo $igw_id

# Attach the internet gateway to vpc (no output)

igw_attach=$(aws ec2 describe-internet-gateways --internet-gateway-ids $igw_id | grep -oP '(?<="VpcId": ")[^"]*')
if [ "$igw_attach" != "$vpc_id" ]; then
    attach_result=$(aws ec2 attach-internet-gateway --internet-gateway-id $igw_id --vpc-id $vpc_id)
    if [ "$attach_result" == "" ]; then
        echo "internet gateway attached to the vpc"
    else 
        echo "Internet gateway AlreadyAssociated"
    fi
else
    echo "Internet gateway already attached to this vpc"
fi
#..........................................................................
#creating the public route table and associate it to thwe 2 public subnets
check_rtb=$(aws ec2 describe-route-tables --filters Name=tag:Name,Values=atapublic-devops90-rtb | grep -oP '(?<="RouteTableId": ")[^"]*' | uniq)

if [ "$check_rtb" == "" ]; then
    echo "public route table will be created"
    public_rtb_id=$(aws ec2 create-route-table --vpc-id $vpc_id --tag-specifications ResourceType=route-table,Tags="[{Key=Name,Value=atapublic-devops90-rtb}]"  --output json | grep -oP '(?<="RouteTableId": ")[^"]*'  | uniq)
    if [ "$public_rtb_id" == "" ]; then
        echo "Error in create public route table"
        exit 1
    fi
    echo "public route table created."

    # create public route 
    route_result=$(aws ec2 create-route --route-table-id $public_rtb_id \
        --destination-cidr-block 0.0.0.0/0 --gateway-id $igw_id | grep -oP '(?<="Return": ")[^"]*')
    echo $route_result
    if [ "$route_result" != "true" ]; then
        echo "public route creation faild"
        continue
    fi
    echo "public route table route created"

else 
    echo "public route table already exist"
    public_rtb_id=$check_rtb
fi

echo $public_rtb_id
# associate public route table to the public subnets
aws ec2 associate-route-table --route-table-id $public_rtb_id --subnet-id $sub1_id
aws ec2 associate-route-table --route-table-id $public_rtb_id --subnet-id $sub2_id
#..........................................................................
#creating the private route table and associate it to the 2 private subnets
check_prtb=$(aws ec2 describe-route-tables --filters Name=tag:Name,Values=ataprivate-devops90-rtb | grep -oP '(?<="RouteTableId": ")[^"]*'  | uniq)
if [ "$check_prtb" = "" ]; then
  echo "private route table will be created"
    private_rtb_id=$(aws ec2 create-route-table --vpc-id $vpc_id --tag-specifications ResourceType=route-table,Tags="[{Key=Name,Value=ataprivate-devops90-rtb}]"  --output json | grep -oP '(?<="RouteTableId": ")[^"]*'  | uniq)
    if [ "$private_rtb_id" == "" ]; then
        echo "Error in create private route table"
        continue
    fi
    echo "private route table route created"

else 
    echo "private route table already exist"
    private_rtb_id=$check_prtb
fi
echo $private_rtb_id
# associate public route table to the public subnets
aws ec2 associate-route-table --route-table-id $private_rtb_id --subnet-id $sub3_id
aws ec2 associate-route-table --route-table-id $private_rtb_id --subnet-id $sub4_id
