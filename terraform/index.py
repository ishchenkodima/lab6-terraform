import boto3

def lambda_handler(event, context):
    # Initialize S3 client
    s3_client = boto3.client('s3')
    
    # Extract bucket name and object key from the event
    source_bucket_name = event['Records'][0]['s3']['bucket']['name']
    object_key = event['Records'][0]['s3']['object']['key']
    
    # Define the target bucket name
    target_bucket_name = 's3-finish'
    
    # Copy the object to the target bucket
    copy_source = {'Bucket': source_bucket_name, 'Key': object_key}
    s3_client.copy_object(Bucket=target_bucket_name, Key=object_key, CopySource=copy_source)
    
    # Return success response
    return {
        'statusCode': 200,
        'body': 'File successfully copied!'
    }
