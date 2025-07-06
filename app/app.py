from dotenv import load_dotenv
import os, boto3, uuid
from datetime import datetime
from flask import Flask, render_template, request, redirect, url_for, flash

load_dotenv()

AWS_ACCESS_KEY_ID = os.getenv("AWS_ACCESS_KEY_ID")
AWS_SECRET_ACCESS_KEY = os.getenv("AWS_SECRET_ACCESS_KEY")
AWS_REGION = os.getenv("AWS_REGION")

S3_BUCKET = os.getenv("BUCKET_NAME")
REGION = os.getenv("AWS_REGION")

s3 = boto3.client("s3", region_name=REGION)

app = Flask(__name__)
app.secret_key = os.urandom(32)

def allowed(filename):
    return filename.lower().endswith((".jpg", ".jpeg", ".png"))

@app.route("/", methods=["GET", "POST"])
def upload():
    if request.method == "POST":
        file = request.files.get("file")
        if not file or not allowed(file.filename):
            flash("Please choose a .jpg or .png file")
            return redirect(url_for("upload"))
        

        # Generate unique key: <uuid>_<original>
        key = f"{uuid.uuid4().hex}_{file.filename}"
        s3.upload_fileobj(
            file, S3_BUCKET, key,
            ExtraArgs={ 
                "ContentType": file.content_type}
        )
        flash(f"Uploaded ✅ - {key}")
        return redirect(url_for("upload"))
    return render_template("index.html")

if __name__ == "__main__":
    app.run(debug=True)