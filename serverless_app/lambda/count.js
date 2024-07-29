import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import pkg from '@aws-sdk/lib-dynamodb';

const { ScanCommand } = pkg;

const client = new DynamoDBClient({});
export const handler = async (event, context) => {
  console.log("---devops90---start-handler");
  console.log("---devops90---event", event);
  const TableName = "devops-raffle";
  try {
    const command = new ScanCommand({
      TableName: TableName,
      Select: "COUNT"
    });

    const count = await client.send(command);
    console.log("---devops90---count", count);
    return count;
  } catch (e) {
    console.log("---devops90---e", e);
    return e.message;
  }
};
