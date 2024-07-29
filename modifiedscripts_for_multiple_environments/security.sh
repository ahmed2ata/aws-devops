key_name="${env}-key_ec2_ssh"
security_group_name="${env}-main_sg"
RULES=(
    '{"IpProtocol": "tcp", "FromPort": 22, "ToPort": 22, "IpRanges": [{"CidrIp": "0.0.0.0/0", "Description": "ssh"}]}'
    '{"IpProtocol": "-1", "UserIdGroupPairs": [{"GroupId": "<your-security-group-id>"}]}'
)

describe_ec2_key() {
    echo "Start describe_ec2_key ..."
    check_ec2_key=$(aws ec2 describe-key-pairs --key-names $key_name 2>&1)
    if echo "$check_ec2_key" | grep -q 'InvalidKeyPair.NotFound'; then
        check_ec2_key=""
    else
        check_ec2_key=$(echo "$check_ec2_key" | grep -oP '(?<="KeyName": ")[^"]*')
    fi
    echo $check_ec2_key
    echo "----------------"
}

create_ec2_key() {
    echo "Start create_ec2_key ..."
    aws ec2 create-key-pair --key-name $key_name --query 'KeyMaterial' --output text > "${key_name}.pem"
    if ! [ -f "${key_name}.pem" ]; then
        echo "Error in creating the EC2 key."
        exit 1
    else
        echo "ec2 key is created."
    fi
    echo "----------------"
}

create_secret() {
    echo "Start create_secret ..."
    delete_secret

    secret_arn=$(aws secretsmanager create-secret --name $key_name --description "EC2 ssh key" --secret-string "$(cat "${key_name}.pem")" | grep -oP "(?<=\"ARN\": \")[^\"]*")
    
    if [ "$secret_arn" == "" ]; then
        echo "Error in creating Secret key."
        exit 1
    else
        echo "Secret key is created."
        rm "${key_name}.pem"
        echo $secret_arn
    fi
    echo "----------------"
}

describe_secret() {
    echo "Start describe_secret ..."
    secret_arn=$(aws secretsmanager describe-secret --secret-id $key_name | grep -oP '(?<="ARN": ")[^"]*')
    echo $secret_arn
    echo "----------------"
}

delete_ec2_key() {
    echo "Start delete_ec2_key ..."
    aws ec2 delete-key-pair --key-name $key_name
    echo "----------------"
}

delete_secret() {
    echo "Start delete_secret ..."
    aws secretsmanager delete-secret --secret-id $key_name --force-delete-without-recovery | grep -oP '(?<="ARN": ")[^"]*'
    echo "----------------"
}

create_sg() {
    echo "Start create_sg ..."

    check_sg=$(aws ec2 describe-security-groups --filters Name=group-name,Values=${security_group_name})
    check_sg=$(echo "$check_sg" | grep -oP '(?<="GroupId": ")[^"]*' | uniq)

    if [ "$check_sg" == "" ]; then
        echo "Security Group will be created"
        sg_id=$(aws ec2 create-security-group --group-name ${security_group_name} --vpc-id $vpc_id --description 'Main Security Group')
        sg_id=$(echo "$sg_id" | grep -oP '(?<="GroupId": ")[^"]*' | uniq)

        if [ "$sg_id" == "" ]; then
            echo "Error in creating the security group"
            exit 1
        fi
        echo $sg_id

        for rule in "${RULES[@]}"; do
            rule=${rule/<your-security-group-id>/$sg_id}
            echo "Adding rule: $rule"
            ADD_RULE_OUTPUT=$(aws ec2 authorize-security-group-ingress --group-id $sg_id --ip-permissions "$rule" 2>&1)
            if [ $? -ne 0 ]; then
                echo "Error adding rule '$rule': $ADD_RULE_OUTPUT"
                echo "deleting the security group ..."
                aws ec2 delete-security-group --group-id $sg_id
                exit 1
            fi
        done
    else
        echo "Security group already exist"
        sg_id=$check_sg
        echo $sg_id
    fi
    echo "----------------"
}

describe_ec2_key
if [ "$check_ec2_key" == "" ]; then
    echo "key is not exists."
    echo "Create key and secret."
    create_ec2_key
    create_secret
else
    describe_secret
    if [ "$secret_arn" == "" ]; then
        echo "key exists but secret not exists."
        echo "Deleting everything then create new key and secret."
        delete_ec2_key
        create_ec2_key
        create_secret
    else
        echo "Nothing created. key and secret are already exists."
        echo "----------------"
    fi
fi

create_sg
