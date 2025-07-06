import boto3, os, io
from datetime import datetime, timezone
from PIL import Image


session = boto3.session.Session()
region = session.region_name
dynamodb = boto3.resource("dynamodb", region_name=region)
table    = dynamodb.Table(os.environ["TABLE_NAME"])
s3       = boto3.client("s3") 
THUMB_SIZE = (256, 256)

def lambda_handler(event, context):
    # S3 PUT event -> single record
    record   = event["Records"][0]
    bucket   = record["s3"]["bucket"]["name"]
    key      = record["s3"]["object"]["key"]
    size     = int(record["s3"]["object"]["size"])
    uploaded = datetime.now(timezone.utc).isoformat()


    # Download image to memory
    raw = io.BytesIO()
    s3.download_fileobj(bucket, key, raw)
    raw.seek(0)

    # Create & upload thumbnail <key>_thumb.jpg
    img = Image.open(raw)
    img.thumbnail(THUMB_SIZE)
    buf = io.BytesIO()
    img.save(buf, "JPEG")
    buf.seek(0)
    thumb_key = f"thumbnails/{key.rsplit('/',1)[-1]}_thumb.jpg"
    s3.upload_fileobj(
        buf, bucket, thumb_key,
        ExtraArgs={"ContentType": "image/jpeg"}
    )

    # Store metadata
    table.put_item(Item={
        "image_id": key,           # partition key
        "upload_time": uploaded,   # sort key alternative
        "size": size,
        "thumbnail": thumb_key
    })
    return {"status": "ok", "key": key, "thumb": thumb_key}