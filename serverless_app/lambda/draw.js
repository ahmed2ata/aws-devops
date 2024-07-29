import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, ScanCommand, UpdateCommand } from "@aws-sdk/lib-dynamodb";

const dynamo = new DynamoDBClient({});
const client = DynamoDBDocumentClient.from(dynamo);

export const handler = async (event) => {
  console.log("---devops90---start-handler");
  console.log("---devops90---event", event);
  let TableName = "devops-raffle";
  let winers_count = 3;
  try {
    console.log("---devops90---try");

    const command = new ScanCommand({
      FilterExpression: "won = :w",
      ExpressionAttributeValues: {
        ":w": "no"
      },
      TableName: TableName
    });

    const data = await client.send(command);
    if (data.Items.length < winers_count) {
      const log_item = "There is no enough data! " + data.Items.length + " only";
      console.log("---devops90---", log_item);
      return log_item;
    }
    
    let indecis = [];
    let winers = [];
    for (let i = 0; i < winers_count; i++) {
      let newIndex = Math.floor(Math.random() * data.Items.length);
      if (indecis.includes(newIndex)) {
        i--;
        continue;
      }
      indecis[i] = newIndex;
      winers.push(data.Items[newIndex]);
    }

    for (let i = 0; i < winers.length; i++) {
      const update_command = new UpdateCommand({
        TableName: TableName,
        Key: {
          email: winers[i].email
        },
        UpdateExpression: 'set won = :r',
        ExpressionAttributeValues: {
          ':r': 'yes'
        }
      });
      const response = await client.send(update_command);
      console.log(response);
    }

    return {
      "indices": indecis,
      "winners": winers
    };

  } catch (err) {
    console.log(err);
    return err.message;
  }
};
