import json
import boto3
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

dynamodb = boto3.resource('dynamodb')
game_table_name = 'TicTacToeGame'  # Replace with the actual game table name if different
ranking_table_name = 'PlayerRanking'  # Replace with the actual ranking table name if different

def lambda_handler(event, context):
    logger.info('Received event: %s', json.dumps(event))
    
    game_table = dynamodb.Table(game_table_name)
    ranking_table = dynamodb.Table(ranking_table_name)
    
    # Extract data from the body of the event
    body = json.loads(event['body'])
    player1 = body['player1']
    player2 = body['player2']
    winner = body['winner']

    logger.info('Player1: %s, Player2: %s, Winner: %s', player1, player2, winner)

    if winner == '1':
        update_ranking(ranking_table, player1, 10)
        update_ranking(ranking_table, player2, -10)
    elif winner == '2':
        update_ranking(ranking_table, player1, -10)
        update_ranking(ranking_table, player2, 10)
    else:
        update_ranking(ranking_table, player1, 0)
        update_ranking(ranking_table, player2, 0)

    logger.info('Rankings updated successfully')

    return {
        'statusCode': 200,
        'body': json.dumps('Rankings updated successfully')
    }

def update_ranking(table, player, points):
    response = table.update_item(
        Key={
            'PlayerId': player
        },
        UpdateExpression="set Score = if_not_exists(Score, :start) + :val",
        ExpressionAttributeValues={
            ':start': 0,
            ':val': points
        },
        ReturnValues="UPDATED_NEW"
    )
    return response
