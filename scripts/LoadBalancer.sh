#!/bin/bash
LB_ARN=$(aws elbv2 create-load-balancer --name ata-lb --subnets subnet-07ec3d2018cadccd3 subnet-075f70ebf46be3a33 --security-groups sg-060201d4e81176b82 --scheme internet-facing --type application | grep -oP '(?<="LoadBalancerArn": ")[^"]*')
echo ${LB_ARN}

TG_ARN=$(aws elbv2 create-target-group --name ata-target-group --protocol HTTP --port 80 --vpc-id vpc-0c324e438c165f802 | grep -oP '(?<="TargetGroupArn": ")[^"]*' )
echo ${TG_ARN}

aws elbv2 register-targets --target-group-arn $TG_ARN --targets Id=i-036fe39897b741e49 Id=i-003d821cd42a5abf0

LR_ARN=$(aws elbv2 create-listener --load-balancer-arn $LB_ARN --protocol HTTP --port 80 --default-actions Type=forward,TargetGroupArn=$TG_ARN | grep -oP '(?<="ListenersArn": ")[^"]*')
echo ${LB_ARN}

