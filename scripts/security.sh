key_name="${env}-key_ec2_ssh"
security_group_name="${env}-main_sg"
RULES=(
    '{"IpProtocol": "tcp", "FromPort": 22, "ToPort": 22, "IpRanges": [{"CidrIp": "0.0.0.0/0", "Description": "ssh"}]}'
    '{"IpProtocol": "-1", "UserIdGroupPairs": [{"GroupId": "<your-security-group-id>"}]}'
)

