#get vpc id
get_vpc_id(){
    vpc_id=$(aws ec2 describe-vpcs --region us-east-1 --filters Name=tag:Name,Values=ata-devops90-vpc | grep -oP '(?<="VpcId": ")[^"]*')
    if [ "$vpc_id" = "" ]; then
      echo "there is not vpc"
      exist 1
    fi
    echo $vpc_id
}
get_vpc_id
#.................................................................
get_subnets_ids(){
    subnet1_id=$(aws ec2 describe-subnets --region us-east-1\
        --filters Name=tag:Name,Values=atasub-public-1-devops90 | grep -oP '(?<="SubnetId": ")[^"]*' )
    if [ "$subnet1_id" = "" ]; then
      echo "there is no subnet1"
      exist 1
    fi
    echo "public subnet1 id is $subnet1_id"
    subnet2_id=$(aws ec2 describe-subnets --region us-east-1\
        --filters Name=tag:Name,Values=atasub-public-2-devops90 | grep -oP '(?<="SubnetId": ")[^"]*' )
    if [ "$subnet2_id" = "" ]; then
      echo "there is no subnet2"
      exist 1
    fi
    echo "public subnet2 id is$subnet2_id"
    
    subnets_ids="${subnet1_id},${subnet2_id}"
    subnets_ids_space="${subnet1_id} ${subnet2_id}"

    echo $subnets_ids
    echo $subnets_ids_space
}
get_subnets_ids
#...........................................................................
get_sg_id(){
    sg_id=$(aws ec2 describe-security-groups --filters Name=tag:Name,Values=ata-SG | grep -oP '(?<="GroupId": ")[^"]*' | uniq)
    if [ "$sg_id" = "" ]; then
      echo "there is no security groups"
      exist 1
    fi
    echo $sg_id
}
get_sg_id
#..................................................................................
create_LB(){
  check_LB=$(aws elb describe-load-balancers --region us-east-1 --query "LoadBalancers[?LoadBalancerName == 'ata-lb']" | grep -oP '(?<="LoadBalancerArn": ")[^"]*')
  if [ "$check_LB" = "" ]; then
   echo "there is no LB we will create one"
   elb_arn=$(aws elbv2 create-load-balancer --name ata-lb --type network --subnets $subnets_ids_space --security-groups $sg_id | grep -oP '(?<="LoadBalancerArn": ")[^"]*' )
   if [ "$elb_arn" == "" ]; then
            echo "Error in create the elb"
            exit 1
   fi
   echo $elb_arn
  else
    echo "elb already exist"
    elb_arn=$check_LB
    echo $elb_arn
  fi
}
create_LB

create_TG(){
  check_tg=$(aws elbv2 describe-target-groups --region us-east-1 --query "TargetGroupArns[?TargetGroupAName == 'ata-TG']" | grep -oP '(?<="TargetGroupArn": ")[^"]*')
  if [ "$check_tg" = "" ]; then
   echo "there is no TG we will create one"
   tg_ARN=$(aws elbv2 create-target-group --name ata-autoscaling-tg \
             --protocol TCP --port 8002 --vpc-id $vpc_id \
             --health-check-interval-seconds 30 \
             --health-check-timeout-seconds 20 \
             --healthy-threshold-count 2 \
             --unhealthy-threshold-count 2 \
             | grep -oP '(?<="TargetGroupArn": ")[^"]*')
   if [ "$tg_ARN" == "" ]; then
            echo "Error in create the elb"
            exit 1
   fi
  else
    echo "TG already exist"
    tg_ARN=$check_tg
  fi    
  echo $tg_ARN  
}
create_TG

create_listener(){
    ls_arn=$(aws elbv2 create-listener --load-balancer-arn "$elb_arn" --protocol TCP --port 80 --default-actions Type=forward,TargetGroupArn="$tg_ARN" | grep -oP '(?<="ListenerArn": ")[^"]*')
    if [ "$ls_arn" == "" ]; then
        echo "Error in create the listener"
        exit 1
    fi
    echo $ls_arn
}
create_listener

create_auto_scaling_group(){

    check_asg=$(aws autoscaling describe-auto-scaling-groups --region us-east-1 --query "AutoScalingGroups[?AutoScalingGroupName == 'ata-devops-asg']" | grep -oP '(?<="AutoScalingGroupARN": ")[^"]*')
    if [ "$check_asg" == "" ]; then
        echo "asg will be created!"
        
        aws autoscaling create-auto-scaling-group \
            --auto-scaling-group-name ata-devops-asg \
            --launch-template LaunchTemplateName=ata-useast1 \
            --target-group-arns $tg_ARN \
            --health-check-type ELB \
            --health-check-grace-period 120 \
            --min-size 2 \
            --desired-capacity 2 \
            --max-size 7 \
            --vpc-zone-identifier "$subnets_ids"

        check2=$(aws autoscaling describe-auto-scaling-groups --region us-east-1 --query "AutoScalingGroups[?AutoScalingGroupName == 'ata-devops-asg']" | grep -oP '(?<="AutoScalingGroupARN": ")[^"]*')
        if [ "$check2" = "" ]; then
          echo "there is no autoscaling group"
          exit 1
        fi
    else
        echo "asg already exist"
        asg_arn=$check_asg
    fi
    echo $check2
}
create_auto_scaling_group
attach_scaling_policy(){
    config=$(cat << EOF
{
    "TargetValue": 50,
    "PredefinedMetricSpecification": {
         "PredefinedMetricType": "ASGAverageCPUUtilization"
    }
}
EOF
)
    config=$( echo $config | tr -d '\n' | tr -d ' ')

    aws autoscaling put-scaling-policy --auto-scaling-group-name ata-devops-asg \
  --policy-name cpu50-target-tracking-scaling-policy \
  --policy-type TargetTrackingScaling \
  --target-tracking-configuration $config
}
attach_scaling_policy